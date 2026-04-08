# Obsidian Integration

Codex-Vault 的 vault 目录可直接作为 Obsidian vault 使用。

## 基础设置

1. 用 Obsidian 打开 vault/ 目录
2. `[[wikilinks]]` 自动渲染为可点击链接
3. Graph View 可视化知识网络
4. YAML frontmatter 支持 Dataview 插件查询

## 推荐配置

- **附件路径**: 设置 Obsidian 附件文件夹为 `sources/` 下的子目录
- **Wikilinks**: 确保设置中启用了 "Use [[Wikilinks]]"（通常默认开启）
- **模板**: 可将 `templates/` 目录设置为 Obsidian 的模板文件夹

## Dataview 查询示例

安装 [Dataview](https://github.com/blacksmithgu/obsidian-dataview) 插件后，可在任何笔记中使用：

```dataview
TABLE tags, date FROM "work/active" SORT date DESC
```

```dataview
LIST FROM #decision SORT date DESC
```

```dataview
TABLE type, description FROM "" WHERE contradictions SORT date DESC
```

## Graph View 技巧

- 使用 Filter 按文件夹聚焦（如只看 brain/ 或 work/active/）
- 颜色分组：按 `type` frontmatter 字段分色
- 孤立节点 = 缺少 wikilinks 的笔记，运行 `/lint` 检测
