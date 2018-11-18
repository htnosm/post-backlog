#!/bin/bash

USAGE() {
  cat <<_EOF
Usage:
  課題の追加:
    ${0} -t "件名" [{-d "詳細" | -f "ファイル名"}] [-s "開始日"] [-e "期限日"] [-a "添付ファイル名"]
  課題の更新:
    ${0} -k "課題キー" [-t "件名"] [{-d "詳細" | -f "ファイル名"}] [-s "開始日"] [-e "期限日"] \
         [-j "状態No"] [-r "完了理由No"] [-a "添付ファイル名"]
  課題コメントの追加:
    ${0} -c -k "課題キー" [{-d "詳細" | -f "ファイル名"}] [-a "添付ファイル名"]

Options:
  -t  課題件名
  -k  課題キー 指定が無い場合は新規登録  指定がある場合は更新
  -d  課題の詳細 (Description)  -c オプションの場合はコメント
  -f  課題の詳細内容ファイル指定  指定がある場合 -d オプションは無効
  -s  開始日 yyyy-MM-dd
  -e  期限日 yyyy-MM-dd
  -j  状態No {1:未対応|2:処理中|3:処理済み|4:完了}
  -r  完了理由No {0:対応済み|1:対応しない|2:無効|3:重複|4:再現しない}
  -a  添付ファイル指定
  -c  コメント追加 (add Comment)
_EOF
  exit
}
ERR_PROC() {
  echo "${*}" ; exit 1
}
GENERATE_URL() {
  _API="${1}"
  _URL="https://${_SPACE}.backlog.jp${_API}?apiKey=${_API_KEY}"
  echo "${_URL}"
}
POST_ATTACHMENT() {
  _URL=$(GENERATE_URL "/api/v2/space/attachment")
  _RES=$(${_CURL} -X POST "${_URL}" -H "Content-Type:multipart/form-data" \
         -F "file=@${_ATTACHMENT_FILE}")
  echo $(echo "${_RES}" | jq -r '.id')
}

which jq >/dev/null 2>&1 || ERR_PROC "jq がインストールされていません"
which curl >/dev/null 2>&1 || ERR_PROC "curl がインストールされていません"
_CONF="$(dirname ${0})/post_backlog.conf"
[ -f "${_CONF}" ] && . "${_CONF}" || ERR_PROC "${_CONF} ファイルが存在しません"
[ -z "${_SPACE}" ] && ERR_PROC "Backlogプロジェクトが設定されていません"
[ -z "${_API_KEY}" ] && ERR_PROC "Backlog API Key が設定されていません"

_CURL="curl -f -s -S"
_CONTENT_TYPE="application/x-www-form-urlencoded"

while getopts :t:k:d:f:s:e:j:r:a:ch OPTS
do
  case "${OPTS}" in
    t) _SUMMARY=${OPTARG} ;;
    k) _ISSUE_KEY=${OPTARG} ;;
    d) _DESCRIPTION=${OPTARG} ;;
    f) _DESCRIPTION_FILE=${OPTARG} ;;
    s) _STARTDATE=${OPTARG} ;;
    e) _DUEDATE=${OPTARG} ;;
    j) _STATUS_ID=${OPTARG} ;;
    r) _RESOLUTION_ID=${OPTARG} ;;
    a) _ATTACHMENT_FILE=${OPTARG} ;;
    c) _COMMENT="yes" ;;
    :|\?|h) USAGE ;;
  esac
done

if [ -n "${_COMMENT}" ]; then
  [ -z "${_ISSUE_KEY}" ] && echo "課題キーが指定されていません" && USAGE
  [ -z "${_DESCRIPTION}" -a -z "${_DESCRIPTION_FILE}" ] && echo "コメント本文が指定されていません" && USAGE
else
  [ -z "${_ISSUE_KEY}" -a -z "${_SUMMARY}" ] && echo "件名が指定されていません" && USAGE
fi
if [ -n "${_DESCRIPTION_FILE}" ]; then
  if [ -f "${_DESCRIPTION_FILE}" ]; then
   _DESCRIPTION=$(cat "${_DESCRIPTION_FILE}")
  else
    ERR_PROC "${_DESCRIPTION_FILE}が存在しません"
  fi
fi

# 設定チェック
if [ -n "${_ISSUE_KEY}" ]; then
  _PROJECT_ID=""
else
  _PARAMS=(
"プロジェクトID:${_PROJECT_ID}"
"種別ID:${_ISSUE_TYPE_ID}"
"優先度ID:${_PRIORITY_ID}"
)
fi
for _PARAM in "${_PARAMS[@]}"; do
  _VALUES=( $(echo "${_PARAM}" | tr ':' ' ') )
  [ -z "${_VALUES[1]}" ] && ERR_PROC "${_VALUES[0]}が設定されていません"
done

if [ -z "${_COMMENT}" ]; then
  _DATAs=(
  "projectId=${_PROJECT_ID}"
  "issueTypeId=${_ISSUE_TYPE_ID}"
  "priorityId=${_PRIORITY_ID}"
  "startDate=${_STARTDATE}"
  "dueDate=${_DUEDATE}"
  "statusId=${_STATUS_ID}"
  "resolutionId=${_RESOLUTION_ID}"
  "assigneeId=${_ASSIGN_ID}"
  )
  for _DATA in "${_DATAs[@]}" ; do
    _VALUE=$(echo "${_DATA}" | sed -e 's%^.*=%%')
    [ -n "${_VALUE}" ] && _PAYLOAD="${_PAYLOAD} --data ${_DATA}"
  done
  for _CATEGORY_ID in ${_CATEGORY_IDs} ; do
    _PAYLOAD="${_PAYLOAD} --data categoryId[]=${_CATEGORY_ID}"
  done
fi
for _NOTIFIED_USER_ID in ${_ASSIGN_ID} ${_NOTIFIED_USER_IDs} ; do
  _PAYLOAD="${_PAYLOAD} --data notifiedUserId[]=${_NOTIFIED_USER_ID}"
done

if [ -n "${_ATTACHMENT_FILE}" ]; then
  if [ -f "${_ATTACHMENT_FILE}" ]; then
    _ATTACHMENT_ID=$(POST_ATTACHMENT)
    [ -n "${_ATTACHMENT_ID}" ] && _PAYLOAD="${_PAYLOAD} --data attachmentId[]=${_ATTACHMENT_ID}"
  else
    ERR_PROC "${_ATTACHMENT_FILE}が存在しません"
  fi
fi

if [ -n "${_ISSUE_KEY}" -a -n "${_COMMENT}" ]; then
  _URL=$(GENERATE_URL "/api/v2/issues/${_ISSUE_KEY}/comments")
  _METHOD="POST"
  _ACT="コメントの追加"
elif [ -n "${_ISSUE_KEY}" ]; then
  _URL=$(GENERATE_URL "/api/v2/issues/${_ISSUE_KEY}")
  _METHOD="PATCH"
  _ACT="課題の更新"
else
  _URL=$(GENERATE_URL "/api/v2/issues")
  _METHOD="POST"
  _ACT="課題の追加"
fi

if [ -n "${_COMMENT}" ]; then
  _RES=$(${_CURL} -X "${_METHOD}" "${_URL}" -H "${_CONTENT_TYPE}" ${_PAYLOAD} \
         --data-urlencode "content=${_DESCRIPTION}")
elif [ -n "${_SUMMARY}" -a -n "${_DESCRIPTION}" ]; then
  _RES=$(${_CURL} -X "${_METHOD}" "${_URL}" -H "${_CONTENT_TYPE}" ${_PAYLOAD} \
         --data-urlencode "summary=${_SUMMARY}" --data-urlencode "description=${_DESCRIPTION}")
elif [ -n "${_SUMMARY}" ]; then
  _RES=$(${_CURL} -X "${_METHOD}" "${_URL}" -H "${_CONTENT_TYPE}" ${_PAYLOAD} \
         --data-urlencode "summary=${_SUMMARY}")
elif [ -n "${_DESCRIPTION}" ]; then
  _RES=$(${_CURL} -X "${_METHOD}" "${_URL}" -H "${_CONTENT_TYPE}" ${_PAYLOAD} \
         --data-urlencode "description=${_DESCRIPTION}")
else
  _RES=$(${_CURL} -X "${_METHOD}" "${_URL}" -H "${_CONTENT_TYPE}" ${_PAYLOAD})
fi

echo "${_RES}"
