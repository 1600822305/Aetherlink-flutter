// 进程内文件搜索库（Rust cdylib），经 dart:ffi 直接调用。
// 请求 / 响应都是 UTF-8 JSON 字符串，见 lib/src/models.dart 的镜像定义。

use regex::{Regex, RegexBuilder};
use serde::{Deserialize, Serialize};
use std::ffi::{c_char, CStr, CString};
use std::fs::File;
use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use walkdir::WalkDir;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SearchRequest {
    directory: String,
    query: String,
    #[serde(default)]
    search_names: bool,
    #[serde(default)]
    search_content: bool,
    #[serde(default)]
    file_types: Vec<String>,
    #[serde(default)]
    skip_dirs: Vec<String>,
    #[serde(default = "default_max_results")]
    max_results: usize,
    #[serde(default)]
    use_regex: bool,
    #[serde(default = "default_max_matches_per_file")]
    max_matches_per_file: usize,
    #[serde(default = "default_max_file_bytes")]
    max_file_bytes: u64,
}

fn default_max_results() -> usize {
    200
}
fn default_max_matches_per_file() -> usize {
    5
}
fn default_max_file_bytes() -> u64 {
    10 * 1024 * 1024
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SearchResponse {
    ok: bool,
    error: String,
    hits: Vec<SearchHit>,
    truncated: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SearchHit {
    path: String,
    is_dir: bool,
    size: u64,
    mtime_ms: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    match_count: Option<usize>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    matches: Vec<MatchLine>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct MatchLine {
    line_number: usize,
    line: String,
}

const MAX_LINE_CHARS: usize = 400;

/// 入参与返回值都是调用方负责释放的 C 字符串：返回值必须交回
/// [aether_rg_free_string]，不能用系统 free（分配器可能不同）。
#[no_mangle]
pub extern "C" fn aether_rg_search(request_json: *const c_char) -> *mut c_char {
    let response = match parse_request(request_json) {
        Ok(request) => run_search(&request),
        Err(error) => SearchResponse {
            ok: false,
            error,
            hits: Vec::new(),
            truncated: false,
        },
    };
    let json = serde_json::to_string(&response).unwrap_or_else(|_| {
        r#"{"ok":false,"error":"failed to encode response","hits":[],"truncated":false}"#
            .to_string()
    });
    CString::new(json)
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub extern "C" fn aether_rg_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { drop(CString::from_raw(ptr)) };
    }
}

fn parse_request(request_json: *const c_char) -> Result<SearchRequest, String> {
    if request_json.is_null() {
        return Err("request is null".to_string());
    }
    let raw = unsafe { CStr::from_ptr(request_json) }
        .to_str()
        .map_err(|error| format!("request is not valid UTF-8: {error}"))?;
    serde_json::from_str(raw).map_err(|error| format!("invalid request: {error}"))
}

fn run_search(request: &SearchRequest) -> SearchResponse {
    let matcher = match build_matcher(request) {
        Ok(matcher) => matcher,
        Err(error) => {
            return SearchResponse {
                ok: false,
                error,
                hits: Vec::new(),
                truncated: false,
            }
        }
    };

    let mut hits = Vec::new();
    let mut truncated = false;
    let walker = WalkDir::new(&request.directory)
        .follow_links(false)
        .sort_by_file_name()
        .into_iter()
        .filter_entry(|entry| {
            !(entry.depth() > 0
                && entry.file_type().is_dir()
                && request
                    .skip_dirs
                    .iter()
                    .any(|dir| entry.file_name() == dir.as_str()))
        });

    for entry in walker {
        if hits.len() >= request.max_results {
            truncated = true;
            break;
        }
        let Ok(entry) = entry else { continue };
        if entry.depth() == 0 {
            continue;
        }
        let name = entry.file_name().to_string_lossy();
        let is_dir = entry.file_type().is_dir();
        let type_ok = request.file_types.is_empty()
            || is_dir
            || request
                .file_types
                .iter()
                .any(|suffix| name.to_lowercase().ends_with(&suffix.to_lowercase()));

        let mut match_count = None;
        let mut matches = Vec::new();
        let mut matched = request.search_names && type_ok && matcher.name_matches(&name);
        if !matched && request.search_content && !is_dir && type_ok {
            if let Some(scan) = scan_content(entry.path(), &matcher, request) {
                match_count = Some(scan.0);
                matches = scan.1;
                matched = true;
            }
        }
        if !matched {
            continue;
        }

        let metadata = entry.metadata().ok();
        hits.push(SearchHit {
            path: entry.path().to_string_lossy().to_string(),
            is_dir,
            size: metadata.as_ref().map(|m| m.len()).unwrap_or(0),
            mtime_ms: metadata
                .and_then(|m| m.modified().ok())
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0),
            match_count,
            matches,
        });
    }

    SearchResponse {
        ok: true,
        error: String::new(),
        hits,
        truncated,
    }
}

enum QueryMatcher {
    Literal(String),
    Pattern(Regex),
}

impl QueryMatcher {
    fn name_matches(&self, name: &str) -> bool {
        match self {
            QueryMatcher::Literal(needle) => name.to_lowercase().contains(needle),
            QueryMatcher::Pattern(regex) => regex.is_match(name),
        }
    }

    fn line_matches(&self, line: &str) -> bool {
        match self {
            QueryMatcher::Literal(needle) => line.to_lowercase().contains(needle),
            QueryMatcher::Pattern(regex) => regex.is_match(line),
        }
    }
}

fn build_matcher(request: &SearchRequest) -> Result<QueryMatcher, String> {
    if request.use_regex {
        RegexBuilder::new(&request.query)
            .case_insensitive(true)
            .build()
            .map(QueryMatcher::Pattern)
            .map_err(|error| format!("invalid regex `{}`: {error}", request.query))
    } else {
        Ok(QueryMatcher::Literal(request.query.to_lowercase()))
    }
}

/// 逐行扫描文件内容；返回（命中总行数, 前 N 条命中行）。
/// 超过大小上限或前 8KB 含 NUL（按二进制处理）的文件直接跳过。
fn scan_content(
    path: &Path,
    matcher: &QueryMatcher,
    request: &SearchRequest,
) -> Option<(usize, Vec<MatchLine>)> {
    let file = File::open(path).ok()?;
    let size = file.metadata().ok()?.len();
    if size > request.max_file_bytes {
        return None;
    }
    if is_probably_binary(path) {
        return None;
    }

    let reader = BufReader::new(file);
    let mut match_count = 0usize;
    let mut matches = Vec::new();
    for (index, line) in reader.split(b'\n').enumerate() {
        let Ok(bytes) = line else { break };
        let text = String::from_utf8_lossy(&bytes);
        let text = text.trim_end_matches('\r');
        if matcher.line_matches(text) {
            match_count += 1;
            if matches.len() < request.max_matches_per_file {
                matches.push(MatchLine {
                    line_number: index + 1,
                    line: clip_chars(text, MAX_LINE_CHARS),
                });
            }
        }
    }

    (match_count > 0).then_some((match_count, matches))
}

fn is_probably_binary(path: &Path) -> bool {
    let Ok(mut file) = File::open(path) else {
        return true;
    };
    let mut buffer = [0u8; 8192];
    match file.read(&mut buffer) {
        Ok(size) => buffer[..size].contains(&0),
        Err(_) => true,
    }
}

fn clip_chars(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }
    text.chars().take(max_chars).collect()
}
