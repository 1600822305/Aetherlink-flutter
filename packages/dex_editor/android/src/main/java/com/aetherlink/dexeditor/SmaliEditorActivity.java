package com.aetherlink.dexeditor;

import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;

import com.aetherlink.dexeditor.editor.EditView;

public class SmaliEditorActivity extends AppCompatActivity {

    public static final String EXTRA_CONTENT = "content";
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_CLASS_NAME = "className";
    public static final String EXTRA_READ_ONLY = "readOnly";
    public static final String EXTRA_SYNTAX_FILE = "syntaxFile";
    public static final String RESULT_CONTENT = "content";
    public static final String RESULT_MODIFIED = "modified";

    private EditView editView;
    private String originalContent;
    private boolean readOnly = false;
    private LinearLayout root;
    private View topSpacer;
    private View bottomSpacer;
    
    // 搜索面板相关
    private LinearLayout searchPanel;
    private EditText searchInput;
    private EditText replaceInput;
    private TextView searchResultText;
    private TextView prevBtn, nextBtn, replaceBtn, replaceAllBtn;
    private int searchMatchCount = 0;
    private int currentMatchIndex = 0;
    private boolean isSearchPanelVisible = false;
    
    // 搜索防抖
    private Handler searchHandler = new Handler(Looper.getMainLooper());
    private Runnable searchRunnable;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Edge-to-Edge 模式
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            getWindow().setStatusBarColor(Color.TRANSPARENT);
            getWindow().setNavigationBarColor(Color.TRANSPARENT);
        }

        // 获取参数
        Intent intent = getIntent();
        originalContent = intent.getStringExtra(EXTRA_CONTENT);
        String title = intent.getStringExtra(EXTRA_TITLE);
        String className = intent.getStringExtra(EXTRA_CLASS_NAME);
        readOnly = intent.getBooleanExtra(EXTRA_READ_ONLY, false);
        String syntaxFile = intent.getStringExtra(EXTRA_SYNTAX_FILE);

        if (originalContent == null) originalContent = "";
        if (title == null) title = "Editor";
        if (syntaxFile == null) syntaxFile = "smali.json";

        // 创建布局
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.parseColor("#1E1E1E"));

        // 顶部安全区域占位
        topSpacer = new View(this);
        topSpacer.setBackgroundColor(Color.parseColor("#2D2D2D"));
        root.addView(topSpacer, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0));

        // 工具栏
        LinearLayout toolbar = createToolbar(title, className);
        root.addView(toolbar);

        // 编辑器
        editView = new EditView(this);
        editView.setLayoutParams(new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0, 1
        ));
        editView.setText(originalContent);
        editView.setSyntaxLanguageFileName(syntaxFile);
        editView.setEditedMode(!readOnly);
        editView.setTypeface(Typeface.MONOSPACE);
        editView.setTextSize(16);
        root.addView(editView);

        // 搜索面板（初始隐藏）
        searchPanel = createSearchPanel();
        searchPanel.setVisibility(View.GONE);
        root.addView(searchPanel);

        // 底部安全区域占位
        bottomSpacer = new View(this);
        bottomSpacer.setBackgroundColor(Color.parseColor("#1E1E1E"));
        root.addView(bottomSpacer, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, 0));

        setContentView(root);

        // 处理安全区域和键盘
        ViewCompat.setOnApplyWindowInsetsListener(root, (v, windowInsets) -> {
            Insets systemBars = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars());
            Insets ime = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
            
            // 更新顶部占位高度
            ViewGroup.LayoutParams topParams = topSpacer.getLayoutParams();
            topParams.height = systemBars.top;
            topSpacer.setLayoutParams(topParams);
            
            // 更新底部占位高度（考虑键盘）
            ViewGroup.LayoutParams bottomParams = bottomSpacer.getLayoutParams();
            bottomParams.height = Math.max(systemBars.bottom, ime.bottom);
            bottomSpacer.setLayoutParams(bottomParams);
            
            return WindowInsetsCompat.CONSUMED;
        });
    }

    private LinearLayout createToolbar(String title, String className) {
        LinearLayout toolbar = new LinearLayout(this);
        toolbar.setOrientation(LinearLayout.HORIZONTAL);
        toolbar.setBackgroundColor(Color.parseColor("#2D2D2D"));
        toolbar.setPadding(16, 8, 16, 8);
        LinearLayout.LayoutParams toolbarParams = new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        );
        toolbar.setLayoutParams(toolbarParams);

        // 返回按钮
        ImageButton backBtn = createIconButton("←");
        backBtn.setOnClickListener(v -> handleBack());
        toolbar.addView(backBtn);

        // 标题
        TextView titleView = new TextView(this);
        titleView.setText(title);
        titleView.setTextColor(Color.WHITE);
        titleView.setTextSize(16);
        titleView.setPadding(16, 0, 16, 0);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(
            0, ViewGroup.LayoutParams.WRAP_CONTENT, 1
        );
        titleView.setLayoutParams(titleParams);
        toolbar.addView(titleView);

        // 撤销按钮
        ImageButton undoBtn = createIconButton("↶");
        undoBtn.setOnClickListener(v -> {
            if (editView.canUndo()) {
                editView.undo();
            }
        });
        toolbar.addView(undoBtn);

        // 重做按钮
        ImageButton redoBtn = createIconButton("↷");
        redoBtn.setOnClickListener(v -> {
            if (editView.canRedo()) {
                editView.redo();
            }
        });
        toolbar.addView(redoBtn);

        // 查找按钮
        ImageButton searchBtn = createIconButton("🔍");
        searchBtn.setOnClickListener(v -> toggleSearchPanel());
        toolbar.addView(searchBtn);

        // 跳转行号按钮
        ImageButton gotoBtn = createIconButton("⤵");
        gotoBtn.setOnClickListener(v -> showGotoLineDialog());
        toolbar.addView(gotoBtn);

        return toolbar;
    }

    private ImageButton createIconButton(String icon) {
        ImageButton btn = new ImageButton(this);
        btn.setBackgroundColor(Color.TRANSPARENT);
        btn.setPadding(24, 16, 24, 16);
        
        // 使用 TextView 作为图标
        TextView tv = new TextView(this);
        tv.setText(icon);
        tv.setTextColor(Color.WHITE);
        tv.setTextSize(20);
        
        FrameLayout container = new FrameLayout(this);
        container.addView(tv);
        
        // 返回简单按钮
        btn.setImageDrawable(null);
        btn.setContentDescription(icon);
        
        // 实际返回一个带文字的按钮
        ImageButton textBtn = new ImageButton(this) {
            @Override
            protected void onDraw(android.graphics.Canvas canvas) {
                super.onDraw(canvas);
                android.graphics.Paint paint = new android.graphics.Paint();
                paint.setColor(Color.WHITE);
                paint.setTextSize(48);
                paint.setTextAlign(android.graphics.Paint.Align.CENTER);
                canvas.drawText(icon, getWidth() / 2f, getHeight() / 2f + 16, paint);
            }
        };
        textBtn.setBackgroundColor(Color.TRANSPARENT);
        textBtn.setMinimumWidth(96);
        textBtn.setMinimumHeight(96);
        
        return textBtn;
    }

    private String lastSearchText = "";

    // 创建 MT 风格的底部搜索面板
    private LinearLayout createSearchPanel() {
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setBackgroundColor(Color.parseColor("#2D2D2D"));
        panel.setPadding(16, 8, 16, 8);

        // 第一行：搜索输入框 + 结果计数
        LinearLayout row1 = new LinearLayout(this);
        row1.setOrientation(LinearLayout.HORIZONTAL);
        row1.setGravity(Gravity.CENTER_VERTICAL);

        // 搜索输入框
        searchInput = new EditText(this);
        searchInput.setHint("查找");
        searchInput.setTextColor(Color.WHITE);
        searchInput.setHintTextColor(Color.GRAY);
        searchInput.setBackgroundResource(R.drawable.round_edittext_bg);
        searchInput.setPadding(24, 16, 24, 16);
        searchInput.setSingleLine(true);
        LinearLayout.LayoutParams searchParams = new LinearLayout.LayoutParams(
            0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        searchParams.setMargins(0, 0, 8, 0);
        searchInput.setLayoutParams(searchParams);
        
        // 实时搜索（带防抖）
        searchInput.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}
            @Override
            public void afterTextChanged(Editable s) {
                // 移除之前的延迟任务，避免重复触发
                if (searchRunnable != null) {
                    searchHandler.removeCallbacks(searchRunnable);
                }
                // 延迟300ms再搜索（用户停止输入后再执行）
                searchRunnable = () -> performSearch();
                searchHandler.postDelayed(searchRunnable, 300);
            }
        });
        row1.addView(searchInput);

        // 搜索结果计数
        searchResultText = new TextView(this);
        searchResultText.setText("0");
        searchResultText.setTextColor(Color.parseColor("#888888"));
        searchResultText.setTextSize(14);
        searchResultText.setPadding(16, 0, 16, 0);
        row1.addView(searchResultText);

        // 关闭按钮
        TextView closeBtn = createTextButton("×");
        closeBtn.setTextSize(24);
        closeBtn.setOnClickListener(v -> hideSearchPanel());
        row1.addView(closeBtn);

        panel.addView(row1);

        // 第二行：上一个、下一个、替换、全部
        LinearLayout row2 = new LinearLayout(this);
        row2.setOrientation(LinearLayout.HORIZONTAL);
        row2.setGravity(Gravity.CENTER_VERTICAL);
        row2.setPadding(0, 8, 0, 0);

        prevBtn = createTextButton("上个");
        prevBtn.setOnClickListener(v -> findPrevious());
        prevBtn.setEnabled(false);
        row2.addView(prevBtn);

        nextBtn = createTextButton("下个");
        nextBtn.setOnClickListener(v -> findNext());
        nextBtn.setEnabled(false);
        row2.addView(nextBtn);

        replaceBtn = createTextButton("替换");
        replaceBtn.setOnClickListener(v -> replaceCurrent());
        replaceBtn.setEnabled(false);
        row2.addView(replaceBtn);

        replaceAllBtn = createTextButton("全部");
        replaceAllBtn.setOnClickListener(v -> replaceAll());
        replaceAllBtn.setEnabled(false);
        row2.addView(replaceAllBtn);

        // 替换输入框
        replaceInput = new EditText(this);
        replaceInput.setHint("替换为");
        replaceInput.setTextColor(Color.WHITE);
        replaceInput.setHintTextColor(Color.GRAY);
        replaceInput.setBackgroundResource(R.drawable.round_edittext_bg);
        replaceInput.setPadding(24, 16, 24, 16);
        replaceInput.setSingleLine(true);
        LinearLayout.LayoutParams replaceParams = new LinearLayout.LayoutParams(
            0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        replaceParams.setMargins(8, 0, 0, 0);
        replaceInput.setLayoutParams(replaceParams);
        row2.addView(replaceInput);

        panel.addView(row2);

        return panel;
    }

    private TextView createTextButton(String text) {
        TextView btn = new TextView(this);
        btn.setText(text);
        btn.setTextColor(Color.parseColor("#63B5F7"));
        btn.setTextSize(14);
        btn.setPadding(24, 12, 24, 12);
        btn.setClickable(true);
        btn.setFocusable(true);
        return btn;
    }

    private void toggleSearchPanel() {
        if (isSearchPanelVisible) {
            hideSearchPanel();
        } else {
            showSearchPanel();
        }
    }

    private void showSearchPanel() {
        searchPanel.setVisibility(View.VISIBLE);
        isSearchPanelVisible = true;
        searchInput.requestFocus();
        // 显示键盘
        InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
        imm.showSoftInput(searchInput, InputMethodManager.SHOW_IMPLICIT);
        
        // 如果有之前的搜索内容，重新搜索
        if (!lastSearchText.isEmpty()) {
            searchInput.setText(lastSearchText);
            searchInput.setSelection(lastSearchText.length());
        }
    }

    private void hideSearchPanel() {
        searchPanel.setVisibility(View.GONE);
        isSearchPanelVisible = false;
        // 隐藏键盘
        InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
        imm.hideSoftInputFromWindow(searchInput.getWindowToken(), 0);
        // 清除高亮
        editView.find("");
        editView.postInvalidate();
    }

    private void performSearch() {
        String text = searchInput.getText().toString();
        lastSearchText = text;
        
        if (text.isEmpty()) {
            searchMatchCount = 0;
            currentMatchIndex = 0;
            searchResultText.setText("0/0");
            editView.find("");
            updateSearchButtonsState();
            return;
        }
        
        // 执行搜索（使用普通文本，非正则）
        editView.find(java.util.regex.Pattern.quote(text));
        
        // 获取匹配数量
        searchMatchCount = editView.getMatchCount();
        currentMatchIndex = 0;
        
        if (searchMatchCount > 0) {
            // 跳转到第一个匹配
            editView.next();
            currentMatchIndex = 1;
            searchResultText.setText(currentMatchIndex + "/" + searchMatchCount);
        } else {
            searchResultText.setText("0/0");
        }
        updateSearchButtonsState();
    }

    private void findNext() {
        if (searchMatchCount > 0) {
            editView.next();
            currentMatchIndex++;
            if (currentMatchIndex > searchMatchCount) {
                currentMatchIndex = 1;
            }
            searchResultText.setText(currentMatchIndex + "/" + searchMatchCount);
        }
    }

    private void findPrevious() {
        if (searchMatchCount > 0) {
            editView.previous();
            currentMatchIndex--;
            if (currentMatchIndex < 1) {
                currentMatchIndex = searchMatchCount;
            }
            searchResultText.setText(currentMatchIndex + "/" + searchMatchCount);
        }
    }

    private void replaceCurrent() {
        if (searchMatchCount > 0 && !readOnly) {
            String replacement = replaceInput.getText().toString();
            editView.replaceFirst(replacement);
            Toast.makeText(this, "已替换当前匹配项", Toast.LENGTH_SHORT).show();
            performSearch(); // 重新搜索更新计数
        }
    }

    private void replaceAll() {
        if (searchMatchCount > 0 && !readOnly) {
            String replacement = replaceInput.getText().toString();
            int count = searchMatchCount;
            editView.replaceAll(replacement);
            Toast.makeText(this, "已替换 " + count + " 处", Toast.LENGTH_SHORT).show();
            performSearch(); // 重新搜索更新计数
        }
    }

    private void updateSearchButtonsState() {
        boolean isEnabled = !searchInput.getText().toString().isEmpty() && searchMatchCount > 0;
        prevBtn.setEnabled(isEnabled);
        nextBtn.setEnabled(isEnabled);
        replaceBtn.setEnabled(isEnabled && !readOnly);
        replaceAllBtn.setEnabled(isEnabled && !readOnly);
        
        // 更新按钮颜色
        int enabledColor = Color.parseColor("#63B5F7");
        int disabledColor = Color.parseColor("#555555");
        prevBtn.setTextColor(isEnabled ? enabledColor : disabledColor);
        nextBtn.setTextColor(isEnabled ? enabledColor : disabledColor);
        replaceBtn.setTextColor((isEnabled && !readOnly) ? enabledColor : disabledColor);
        replaceAllBtn.setTextColor((isEnabled && !readOnly) ? enabledColor : disabledColor);
    }

    private void showGotoLineDialog() {
        EditText input = new EditText(this);
        input.setInputType(InputType.TYPE_CLASS_NUMBER);
        input.setHint("输入行号");
        input.setTextColor(Color.WHITE);
        input.setHintTextColor(Color.GRAY);
        input.setPadding(48, 32, 48, 32);

        new AlertDialog.Builder(this)
            .setTitle("跳转到行")
            .setView(input)
            .setPositiveButton("跳转", (d, w) -> {
                String text = input.getText().toString();
                if (!text.isEmpty()) {
                    try {
                        int line = Integer.parseInt(text);
                        editView.gotoLine(line);
                    } catch (NumberFormatException e) {
                        Toast.makeText(this, "请输入有效的行号", Toast.LENGTH_SHORT).show();
                    }
                }
            })
            .setNegativeButton("取消", null)
            .show();
    }

    private void handleBack() {
        String currentContent = editView.getBuffer().toString();
        if (!currentContent.equals(originalContent)) {
            // 有修改，询问是否保存
            new android.app.AlertDialog.Builder(this)
                .setTitle("保存修改?")
                .setMessage("内容已修改，是否保存?")
                .setPositiveButton("保存", (d, w) -> saveAndFinish())
                .setNegativeButton("放弃", (d, w) -> {
                    setResult(RESULT_CANCELED);
                    finish();
                })
                .setNeutralButton("取消", null)
                .show();
        } else {
            setResult(RESULT_CANCELED);
            finish();
        }
    }

    private void saveAndFinish() {
        String currentContent = editView.getBuffer().toString();
        Intent result = new Intent();
        result.putExtra(RESULT_CONTENT, currentContent);
        result.putExtra(RESULT_MODIFIED, !currentContent.equals(originalContent));
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onBackPressed() {
        handleBack();
    }
}
