#!/bin/bash

USAGE() {
  cat <<_EOF
Usage: ${0} [-p "プロジェクト"] \\
         [-i "種別"] [-u "優先度"] [-c "カテゴリー1,カテゴリー2,..."] [-l]
Options:
  -p  プロジェクト名 (Project)
  -i  種別 (Issue type)
  -u  優先度
  -c  カテゴリーリスト、カンマ区切り (Category)
  -l  ユーザリスト出力
_EOF
  exit
}
ERR_PROC() {
  echo "${*}" ; exit 1
}
GENERATE_URL() {
  _API="${1}"
  _URL="https://${_SPACE}.backlog.jp/${_API}?apiKey=${_API_KEY}"
  echo "${_URL}"
}

which jq >/dev/null 2>&1 || ERR_PROC "jq がインストールされていません"
_CONF="$(dirname ${0})/post_backlog.conf"
[ -f "${_CONF}" ] && . "${_CONF}" || ERR_PROC "${_CONF} ファイルが存在しません"
[ -z "${_SPACE}" ] && ERR_PROC "Backlogプロジェクトが設定されていません"
[ -z "${_API_KEY}" ] && ERR_PROC "Backlog API Key が設定されていません"

while getopts :p:i:u:c:lh OPTS
do
  case "${OPTS}" in
    p) _PROJECT=${OPTARG} ;;
    i) _ISSUE_TYPE=${OPTARG} ;;
    u) _PRIORITY=${OPTARG} ;;
    c) _CATEGORIES=${OPTARG} ;;
    l) _USER_LIST=1 ;;
    :|\?|h) USAGE ;;
  esac
done

# プロジェクトID取得
_URL=$(GENERATE_URL "/api/v2/projects/${_PROJECT}")
_RES_PROJECT_ID=$(curl -f -s -S "${_URL}" | jq -r '.id')
[ -z "${_RES_PROJECT_ID}" ] && ERR_PROC "プロジェクト ${_PROJECT} が存在しません"

# 種別ID取得
_URL=$(GENERATE_URL "/api/v2/projects/${_RES_PROJECT_ID}/issueTypes")
_RES_ISSUE_TYPE_ID=$(curl -f -s -S "${_URL}" | jq -r '.[] | select(.name == "'${_ISSUE_TYPE}'").id')

# 優先度ID取得
_URL=$(GENERATE_URL "/api/v2/priorities")
_RES_ISSUE_TYPE_ID=$(curl -f -s -S "${_URL}" | jq -r '.[] | select(.name == "'${_PRIORITY}'").id')

# ユーザリスト取得
_URL=$(GENERATE_URL "/api/v2/projects/${_RES_PROJECT_ID}/users")
_RES_USERS=$(curl -f -s -S "${_URL}")

# 登録者ID取得
_URL=$(GENERATE_URL "/api/v2/users/myself")
_RES=( $(curl -f -s -S "${_URL}" | jq -r '[ .id, .name ] | @csv' | tr ',' ' ') )
_RES_CREATE_USER_ID="${_RES[0]}"
_RES_CREATE_USER="${_RES[1]//\"/}"
_CHECK=$(echo "${_RES_USERS}" | jq -r '.[] | select(.id == '${_RES_CREATE_USER_ID}').id')
[ -z "${_CHECK}" ] && ERR_PROC "ユーザ ${_RES_CREATE_USER} はプロジェクト ${_PROJECT} に存在しません"

# カテゴリーID取得
if [ -n "${_CATEGORIES}" ]; then
  _URL=$(GENERATE_URL "/api/v2/projects/${_RES_PROJECT_ID}/categories")
  _RES=$(curl -f -s -S "${_URL}")
  _CATEGORY_IDs=""
  _IFS_BEF="${IFS}" && IFS=','
  for _CATEGORY in ${_CATEGORIES} ; do
    _RES_CATEGORY_ID=$(echo "${_RES}" | jq -r '.[] | select(.name == "'${_CATEGORY}'").id')
    _RES_CATEGORY_IDs="${_RES_CATEGORY_IDs}${_RES_CATEGORY_ID} "
  done
  IFS="${_IFS_BEF}"
fi

# 取得内容出力
cat <<_EOF
プロジェクト: ${_PROJECT} ( ${_RES_PROJECT_ID:-"存在しません"} )
種別: ${_ISSUE_TYPE} ( ${_RES_ISSUE_TYPE_ID:-"存在しません"} )
優先度: ${_PRIORITY} ( ${_RES_ISSUE_TYPE_ID:-"存在しません"} )
登録者: ${_RES_CREATE_USER} ( ${_RES_CREATE_USER_ID:-"存在しません"} )
カテゴリー: ${_CATEGORIES} ( ${_RES_CATEGORY_IDs})
_EOF
if [ -n "${_USER_LIST}" ]; then
  cat <<_EOF
##### ユーザ 一覧
$(echo "${_RES_USERS}" | jq -r -c '.[] | { name:.name, id:.id }' | sort)
_EOF
fi
