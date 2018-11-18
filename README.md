# post-backlog
Backlog への 課題の追加・更新・コメント追加

## 概要

- [プロジェクト管理 & コラボレーションツール \| Backlog](https://backlog.com/ja/)

Backlog への課題操作(課題の追加、課題の更新およびコメント追加)を行う。

## 要件

bash で動作

- [curl](https://curl.haxx.se/)
- [jq](https://stedolan.github.io/jq/)

## 設定

### APIキーの発行

- [APIの設定 \- Backlog（バックログ）](https://backlog.com/ja/help/usersguide/personal-settings/userguide2378/)

### post_backlog.conf を作成

発行したAPIキー、既定値として利用する プロジェクト名・種別名・優先度・カテゴリー を設定する

### ID取得

以下の実行結果を元に登録者ID、既定値として利用する プロジェクトID・種別ID・優先度ID・カテゴリーID を設定する

```bash
# HELP出力
./get_backlog_ids.sh -h

# ID出力
./get_backlog_ids.sh
# ユーザーID一覧出力付与
./get_backlog_ids.sh -l
```

## 使い方

```bash
# HELP出力
./post_backlog_issue.sh -h
```

- 実行時オプション未指定の場合、conf 内容を使用して実行する。

### 課題の追加

```bash
# 例
## 最小オプション
./post_backlog_issue.sh -t "件名"
## 詳細欄記載
./post_backlog_issue.sh -t "件名" -d "詳細"
## テキストファイルから詳細欄記載
./post_backlog_issue.sh -t "件名" -f "message.txt"
```

### 課題の更新

- 追記ではなく上書き

```bash
# 例
## テキストファイルから詳細欄更新
./post_backlog_issue.sh -k "課題キー" -f "message.txt"
```

### コメント追加

```bash
# 例
## コメント追加
./post_backlog_issue.sh -k "課題キー" -d "コメント"
```
