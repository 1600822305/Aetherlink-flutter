/// deck.json 的 JSON Schema（draft-07 子集）——格式的单一权威来源。
///
/// 与解析器（deck_document.dart 及其 part 文件）保持同步：字段、枚举、
/// 别名（fontSize≡size、chartType≡chart、text 简写）都在这里声明。
/// `pptx_schema` 工具原样返回它；解析报错时提示模型调 schema 自查，
/// 避免技能文档 prose 与解析器漂移。
library;

/// deck.json 顶层 JSON Schema。
const Map<String, Object?> kDeckJsonSchema = {
  r'$schema': 'http://json-schema.org/draft-07/schema#',
  'title': 'deck.json',
  'description':
      'AetherLink PPT 工具的 deck 源格式：pptx_render/pptx_check 的输入。'
      '解析器对部分字段有别名容错（见各字段 description）。',
  'type': 'object',
  'required': ['slides'],
  'properties': {
    'layout': {
      'enum': ['16x9', '16:9', '4x3', '4:3'],
      'description': '画布比例，默认 16x9（13.33×7.5 英寸）',
    },
    'title': {'type': 'string', 'description': '文档标题（写入 docProps）'},
    'style': {
      'description':
          '内置风格 id（调 pptx_styles 列出）或内联风格对象；'
          '套用后元素可省略颜色/字体自动推导',
      'oneOf': [
        {'type': 'string'},
        {'type': 'object'},
      ],
    },
    'slides': {
      'type': 'array',
      'minItems': 1,
      'items': {r'$ref': '#/definitions/slide'},
    },
  },
  'definitions': {
    'slide': {
      'type': 'object',
      'description': '一页：elements（绝对定位）与 layout（布局声明）至少给一个，可混用',
      'properties': {
        'background': {r'$ref': '#/definitions/color'},
        'notes': {'type': 'string', 'description': '演讲者备注'},
        'layout': {r'$ref': '#/definitions/pageLayout'},
        'elements': {
          'type': 'array',
          'items': {r'$ref': '#/definitions/element'},
        },
      },
    },
    'color': {
      'type': 'string',
      'pattern': '^#?[0-9a-fA-F]{6}\$',
      'description': '6 位 hex RGB（如 "1A73E8"），不带 alpha；透明度是独立字段',
    },
    'frame': {
      'description': '所有元素共有的几何字段（单位英寸，画布左上角为原点）',
      'properties': {
        'x': {'type': 'number'},
        'y': {'type': 'number'},
        'w': {'type': 'number', 'minimum': 0},
        'h': {'type': 'number', 'minimum': 0},
      },
      'required': ['x', 'y', 'w', 'h'],
    },
    'element': {
      'type': 'object',
      'required': ['type', 'x', 'y', 'w', 'h'],
      'properties': {
        'type': {
          'enum': ['text', 'shape', 'image', 'table', 'chart', 'infographic'],
        },
      },
      'allOf': [
        {r'$ref': '#/definitions/frame'},
      ],
      'description':
          '按 type 分派：text→textElement，shape→shapeElement，'
          'image→imageElement，table→tableElement，chart→chartElement，'
          'infographic→infographicElement',
    },
    'textElement': {
      'type': 'object',
      'description':
          '文本框。两种写法：完整 paragraphs[].runs[]，或简写顶层 "text" 字符串'
          '（\\n 分段，可配 size/fontSize/bold/color/font/align）',
      'properties': {
        'paragraphs': {
          'type': 'array',
          'minItems': 1,
          'items': {r'$ref': '#/definitions/paragraph'},
        },
        'text': {'type': 'string', 'description': '简写：与 paragraphs 二选一'},
        'valign': {
          'enum': ['top', 'middle', 'bottom'],
        },
        'fill': {r'$ref': '#/definitions/color'},
        'lineSpacing': {
          'type': 'number',
          'exclusiveMinimum': 0,
          'description': '行距倍数，如 1.2',
        },
      },
    },
    'paragraph': {
      'type': 'object',
      'required': ['runs'],
      'properties': {
        'runs': {
          'type': 'array',
          'minItems': 1,
          'items': {r'$ref': '#/definitions/run'},
        },
        'bullet': {'type': 'boolean'},
        'indentLevel': {'type': 'integer', 'minimum': 0, 'maximum': 8},
        'align': {
          'enum': ['left', 'center', 'right'],
        },
      },
    },
    'run': {
      'type': 'object',
      'required': ['text'],
      'properties': {
        'text': {'type': 'string'},
        'bold': {'type': 'boolean'},
        'italic': {'type': 'boolean'},
        'size': {
          'type': 'number',
          'exclusiveMinimum': 0,
          'description': '字号 pt；别名 fontSize 也接受',
        },
        'color': {r'$ref': '#/definitions/color'},
        'font': {'type': 'string'},
      },
    },
    'shapeElement': {
      'type': 'object',
      'required': ['shape'],
      'properties': {
        'shape': {
          'enum': ['rect', 'roundRect', 'ellipse', 'line', 'pie'],
        },
        'fill': {r'$ref': '#/definitions/color'},
        'fillTransparency': {'type': 'integer', 'minimum': 0, 'maximum': 100},
        'lineColor': {r'$ref': '#/definitions/color'},
        'lineWidth': {'type': 'number', 'exclusiveMinimum': 0},
        'radius': {
          'type': 'number',
          'minimum': 0,
          'maximum': 0.5,
          'description': 'roundRect 圆角（相对短边比例）',
        },
        'angleStart': {'type': 'number', 'description': 'pie 起始角（度）'},
        'angleEnd': {'type': 'number', 'description': 'pie 结束角（度）'},
      },
    },
    'imageElement': {
      'type': 'object',
      'description': 'data（base64 PNG/JPEG）与 src（URL/工作区路径）二选一，优先 src 省 token',
      'properties': {
        'data': {'type': 'string'},
        'src': {'type': 'string'},
      },
    },
    'tableElement': {
      'type': 'object',
      'required': ['rows'],
      'properties': {
        'rows': {
          'type': 'array',
          'minItems': 1,
          'description': '行数组；单元格是字符串、{text}、或 {runs, fill, align}',
          'items': {'type': 'array', 'minItems': 1},
        },
        'colWidths': {
          'type': 'array',
          'items': {'type': 'number', 'exclusiveMinimum': 0},
          'description': '各列宽（英寸），长度须等于列数；省略 = 均分',
        },
        'headerFill': {r'$ref': '#/definitions/color'},
        'headerColor': {r'$ref': '#/definitions/color'},
        'borderColor': {r'$ref': '#/definitions/color'},
      },
    },
    'chartElement': {
      'type': 'object',
      'required': ['chart', 'categories', 'series'],
      'properties': {
        'chart': {
          'enum': [
            'bar', 'line', 'pie', 'doughnut', 'area',
            'scatter', 'stackedBar', 'horizontalBar', 'radar',
          ],
          'description': '别名 chartType 也接受',
        },
        'title': {'type': 'string'},
        'categories': {
          'type': 'array',
          'minItems': 1,
          'items': {'type': 'string'},
        },
        'series': {
          'type': 'array',
          'minItems': 1,
          'items': {
            'type': 'object',
            'required': ['name', 'values'],
            'properties': {
              'name': {'type': 'string'},
              'values': {
                'type': 'array',
                'items': {'type': 'number'},
                'description': '长度须等于 categories 长度',
              },
              'color': {r'$ref': '#/definitions/color'},
            },
          },
        },
      },
    },
    'infographicElement': {
      'type': 'object',
      'required': ['kind'],
      'description': '形状合成图（导出后是可编辑形状组）；单值类只收 value/label，不收 items',
      'properties': {
        'kind': {
          'enum': ['progress', 'kpi', 'waffle', 'timeline', 'funnel', 'gauge'],
        },
        'value': {'description': 'progress/waffle/gauge 是 0-100 数值；kpi 是字符串'},
        'label': {'type': 'string'},
        'trend': {'type': 'string', 'description': 'kpi 专用，如 "+12%" / "-3%"'},
        'steps': {'type': 'array', 'description': 'timeline 专用'},
        'stages': {'type': 'array', 'description': 'funnel 专用'},
      },
    },
    'pageLayout': {
      'type': 'object',
      'required': ['type'],
      'description': '页级布局声明：引擎负责定位/间距/边界，agent 只填内容',
      'properties': {
        'type': {
          'enum': [
            'cover', 'toc', 'section', 'end',
            'focus', 'split', 'asymmetric', 'columns',
            'hierarchy', 'hero', 'grid',
          ],
        },
        'title': {'type': 'string'},
        'subtitle': {'type': 'string'},
        'label': {'type': 'string'},
        'lead': {'type': 'string'},
        'meta': {'type': 'string'},
        'items': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'toc/end 的条目列表',
        },
        'cards': {
          'type': 'array',
          'description':
              '内容页卡片；type 为 text/data/list/tags/process/big_number',
          'items': {
            'type': 'object',
            'properties': {
              'type': {
                'enum': ['text', 'data', 'list', 'tags', 'process', 'big_number'],
              },
            },
          },
        },
      },
    },
  },
};
