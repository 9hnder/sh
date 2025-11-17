#!/bin/bash
#=============================================================================
#
#          FILE:  ToggleTouchPad.sh
#
#   DESCRIPTION:  タッチパッドの 有効/無効 状態を反転する.
#
#       OPTIONS:  usage() 関数を参照.
#  REQUIREMENTS:  "使用コマンドの定義" セクションを参照.
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  9hnder(Ken Shirakawa)
#       COMPANY:  Electoronic Cybernized co., ltd.
#    POWERED-BY:  vim - Vi IMproved, bash-support vim plugin
#       VERSION:  1.0.3
#       CREATED:  2025-10-07
#       UPDATED:  2025-10-08 * notify-send でデスクトップ通知するよう改良.
#              :  2025-10-20 * which -s は最新バージョンでしか使えなかった為、
#              :               >/dev/null に変更. ＆ which -> type -P に変更.
#              :  2025-11-16 * デバイス名に TouchPad が含まれず、 Synaptics が
#              :               替わりに含まれている場合に対応.
#=============================================================================

##############################################################################
# 使用コマンドの定義                                           Define Commands
##############################################################################
# 外部コマンド
# NOTE: はじめにエイリアス展開を許可. 全エイリアスをクリアしておく.
#       シェルの内部コマンドを除いた外部コマンドは、ここで全てエイリアスとして
#       定義しておく. これはユーザー環境に応じ パスの変更, 亜種コマンドへ代替
#       し易くする目的. またコマンドの存在を簡易検査するため.
shopt -s expand_aliases
unalias -a
alias cat=\cat
alias sed=\sed
alias grep=\grep
alias logger=\logger
alias xinput=\xinput
alias notify-send=\notify-send
# 外部スクリプト


##############################################################################
# 定数定義                                                    Define Constants
##############################################################################
readonly DEF_VERSION=1.0.3
readonly DEF_EXIT_SUCCESS=0
readonly DEF_EXIT_FAILURE=1
readonly DEF_OPT_MODE_TOGGLE='toggle'
readonly DEF_OPT_MODE_ENABLE='enable'
readonly DEF_OPT_MODE_DISABLE='disable'
readonly DEF_OPT_MODE_STATUS='status'


##############################################################################
# 広域変数定義                                         Define Global Variables
##############################################################################
gs_result=''									# 関数の結果文字列(共用)
let gi_result=0									# 関数の結果整数(共用)
let gi_verbose_flag=0							# 冗長な表示フラグ


##############################################################################
# 関数定義                                                     Define Funcions
##############################################################################


#===  FUNCTION  ==============================================================
#          NAME:  message_output()
#   DESCRIPTION:  指定されたメッセージを出力する. 端末上で実行された場合は標準
#                 出力、または標準エラー出力へ. それ以外はデスクトップへ通知を
#                 発する.
#    PARAMETERS:  $1: s_message:メッセージの内容.
#                 $2: i_output_dest:出力先. { 1:標準出力(Default),
#                                             2:標準エラー出力 }
#       RETURNS:  結果 { DEF_EXIT_SUCCESS:成功, DEF_EXIT_FAILURE:失敗 }
#        OUTPUT:  結果を端末またはデスクトップ通知へ出力.
#=============================================================================
function message_output()
{
	local     s_message="$1"
	local let i_output_dest=${2:-1}

	if [ $# -eq 0 -o $# -ge 3 ] ; then
		return $DEF_EXIT_FAILURE
	fi

	# 端末との接続状況に応じて出力先を変更する.
	# NOTE: -t 0 は標準入力と接続されているとき、すなわち CLI で実行中の時のみ
	#       True を返す. 標準出力(1), 標準エラー出力(2) はファイルや /dev/null
	#       などへ出力されていると未接続と見なされるため、使用しない.
	if   [ $i_output_dest -eq 1 -a -t 0 ] ; then
		echo "$s_message"
	elif [ $i_output_dest -eq 2 -a -t 0 ] ; then
		echo "$s_message" >&2
	elif [ $i_output_dest -eq 1 -a "$DISPLAY" != '' ] ; then
		notify-send -t 4000 --app-name=ToggleTouchPad.sh -i input-touchpad \
		 'ToggleTouchPad.sh' "$s_message"
	elif [ $i_output_dest -eq 2 -a "$DISPLAY" != '' ] ; then
		# エラー出力は --urgency=critical を使い自動的には消えない通知にする.
		notify-send -t 8000 --app-name=ToggleTouchPad.sh -i dialog-error \
		 --category=device --urgency=critical 'ToggleTouchPad.sh' "$s_message"
	else
		# ここは本来通ることはないはず. syslog に出力する.
		logger -t ${0##*/} -i -p user.err \
		 "ERROR: 論理エラー. 出力先が見つかりません: $i_output_dest, $DISPLAY"
		logger -t ${0##*/} -i -p user.err "$s_message"
	fi

	return $DEF_EXIT_SUCCESS
}

#===  FUNCTION  ==============================================================
#          NAME:  touchpad_enable()
#   DESCRIPTION:  タッチパッドを有効化する.
#    PARAMETERS:  $1: s_device:タッチパッドのデバイス名.
#       RETURNS:  結果 { DEF_EXIT_SUCCESS:成功, DEF_EXIT_FAILURE:失敗 }
#        OUTPUT:  エラーが出ない限り無し.
#=============================================================================
function touchpad_enable()
{
	local s_device=$1

	if [ $# -eq 0 ] ; then
		return $DEF_EXIT_FAILURE
	fi

	xinput enable "$s_device"
	if [ $? -ne 0 ] ; then
		message_output 'ERROR: xinput enable コマンドが失敗しました。' 2
		return $DEF_EXIT_FAILURE
	fi
	message_output "$s_device を有効化しました。"

	return $DEF_EXIT_SUCCESS
}

#===  FUNCTION  ==============================================================
#          NAME:  touchpad_disable()
#   DESCRIPTION:  タッチパッドを無効化する.
#    PARAMETERS:  $1: s_device:タッチパッドのデバイス名.
#       RETURNS:  結果 { DEF_EXIT_SUCCESS:成功, DEF_EXIT_FAILURE:失敗 }
#        OUTPUT:  エラーが出ない限り無し.
#=============================================================================
function touchpad_disable()
{
	local s_device=$1

	if [ $# -eq 0 ] ; then
		return $DEF_EXIT_FAILURE
	fi

	xinput disable "$s_device"
	if [ $? -ne 0 ] ; then
		message_output 'ERROR: xinput disable コマンドが失敗しました。' 2
		return $DEF_EXIT_FAILURE
	fi
	message_output "$s_device を無効化しました。"

	return $DEF_EXIT_SUCCESS
}

#===  FUNCTION  ==============================================================
#          NAME:  get_touchpad_devicename_and_status()
#   DESCRIPTION:  タッチパッドのデバイス名と現在の状態を取得する.
#    PARAMETERS:  --
#       RETURNS:  結果 { DEF_EXIT_SUCCESS:成功, DEF_EXIT_FAILURE:失敗 }
#        RESULT:  gs_result:タッチパッドのデバイス名.
#              :  gi_result:現在の状態フラグ. {0:無効, 1:有効}
#        OUTPUT:  エラーが出ない限り無し.
#           BUG:  タッチパッドが 2つ以上ある場合は選択不可. 未対応.
#=============================================================================
function get_touchpad_devicename_and_status()
{
	local     s_result=''				# コマンド結果を一時的に格納.
	local     s_device=''				# タッチパッドのデバイス名.
	local let i_now_status_flag=0		# 現在の状態フラグ. {0:無効, 1:有効}

	# NOTE: プログラム的には list サブコマンドの出力から デバイス名 の代わりに
	#       id を取得して使う方がスマートではある.  しかし、デバイス名の方が端
	#       末や通知への出力にも利用でき、ユーザーに優しい.
	s_result=`xinput list --name-only | grep -m 1 -Ei 'TouchPad|Synaptics'`
	if [ $? -ne 0 ] ; then
		message_output 'ERROR: xinput list コマンドが失敗しました。' 2
		return $DEF_EXIT_FAILURE
	fi
	s_device=`echo "$s_result" | sed -r 's/^∼ //g'`

	if [ "$s_device" == "$s_result" ] ; then
		let i_now_status_flag=1
		if [ $gi_verbose_flag -eq 1 ] ; then
			message_output "現在の $s_device の状態：有効。"
		fi
	elif [ $gi_verbose_flag -eq 1 ] ; then
		message_output "現在の $s_device の状態：無効。"
	fi

	let gi_result=$i_now_status_flag
	gs_result="$s_device"
}

#===  FUNCTION  ==============================================================
#          NAME:  toggle_touchpad()
#   DESCRIPTION:  タッチパッドの 有効/無効 状態を反転する.
#    PARAMETERS:  $1: s_device:タッチパッドのデバイス名.
#              :  $2: i_now_status_flag:現在の状態フラグ {0:無効, 1:有効}
#       RETURNS:  結果 { DEF_EXIT_SUCCESS:成功, DEF_EXIT_FAILURE:失敗 }
#        OUTPUT:  エラーが出ない限り無し.
#=============================================================================
function toggle_touchpad()
{
	local     s_device="$1"
	local let i_now_status_flag=$2

	if [ $# -lt 2 ] ; then
		return $DEF_EXIT_FAILURE
	fi

	# 現在の状態から反転させる.
	if [ $i_now_status_flag -eq 0 ] ; then
		touchpad_enable "$s_device"
	else
		touchpad_disable "$s_device"
	fi
	if [ $? -ne 0 ] ; then
		return $DEF_EXIT_FAILURE
	fi

	return $DEF_EXIT_SUCCESS
}

#===  FUNCTION  ==============================================================
#          NAME:  exists_needed_commands()
#   DESCRIPTION:  このスクリプトで必要なコマンドが揃っているか簡易検査する.
#    PARAMETERS:  ---
#       RETURNS:  結果 { DEF_EXIT_SUCCESS:成功, DEF_EXIT_FAILURE:失敗 }
#=============================================================================
function exists_needed_commands()
{
	# BUG: 現状、先頭のトークンがコマンドと仮定して調べる仕様である. このため
	#      トークンの前に変数定義(e.g. 'LANG=C grep -E')があると それを誤って
	#      コマンドとして調べてしまうだろう. しかし、これは回避し難いため仕様
	#      上の制限とする.
	local s_commands=$( alias -p | sed -r -e 's/^alias //' -e 's/[^=]+=//' \
	  -e "s/['\"\`\\]//g" -e 's/ .+$//' )

	type -P $s_commands >/dev/null
	if [ $? -ne 0 ] ; then
		echo "ERROR: 必要なコマンドのいずれかが不足しています: $s_commands" >&2
		return $DEF_EXIT_FAILURE
	fi

	return $DEF_EXIT_SUCCESS
}

#===  FUNCTION  ==============================================================
#          NAME:  version
#   DESCRIPTION:  バージョンの表示
#    PARAMETERS:  $1: 出力先 { 1:標準出力, 2:標準エラー出力 }
#       RETURNS:  ---
#=============================================================================
function version()
{
	local let i_output=${1:-1}

	printf '%s - version %s\n' ${0##*/} $DEF_VERSION >&$i_output
	local s_text=`cat <<- EOT

	Copyright (C) 2025 Electoronic Cybernized co., ltd.
	License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
	This is free software. you are free to change and redistribute it.
	There is NO warranty.

	EOT
	`
	echo "$s_text" >&$i_output
}

#===  FUNCTION  ==============================================================
#          NAME:  usage
#   DESCRIPTION:  使用方法の表示
#    PARAMETERS:  $1: 出力先 { 1:標準出力, 2:標準エラー出力 }
#       RETURNS:  ---
#=============================================================================
function usage()
{
	local let i_output=${1:-1}
	printf "Usage: %s [-v][-e|-d]\n" ${0##*/} >&$i_output
	printf "Usage: %s [-Vh]\n" ${0##*/} >&$i_output
	s_text=`cat <<- EOT
	    -v,       --verbose     実行前の状態も含め、詳しく表示。
	    -m MODE,  --mode=MODE   実行モードを指定。
	                            MODE={ toggle:  状態を反転する(Default),
	                                   enable:  有効化する,
	                                   disable: 無効化する,
	                                   status:  状態の表示のみ }
	    -V,       --version     バージョンの表示。
	    -h,       --help        使用方法の表示。

	タッチパッドの 有効/無効 状態を反転する。すなわち、有効な状態で実行すれば
	無効化し、無効な状態で実行すれば有効化する。

	【動作条件】
	Linux の GUI 環境(Xorg/Wayland セッション)下でのみ動作。 xinput コマンドが
	必要。デスクトップ通知用に notify-send コマンドが必要。
	ただし、もし libinput 以外のドライバ(e.g. evdev や synaptics) を使用してい
	る場合は動作しないかもしれない。

	EOT
	`
    echo "$s_text" >&$i_output
}

#===  FUNCTION  ==============================================================
#          NAME:  translate_long_options
#   DESCRIPTION:  --xxx 形式のロングオプションを対応する短いオプションに変換.
#    PARAMETERS:  $@: コマンドライン・オプション.
#       RETURNS:  ---
#        OUTPUT:  gas_result: 変換後のコマンドライン・オプションを格納.
#=============================================================================
function translate_long_options()
{
	local      s_arg=''
	local      s_arg_param=''
	local let  i_index=0
	gas_result=()

	for s_arg in "$@"
	do
		s_arg_param="${s_arg##--*=}"
		if [ "$s_arg" != "$s_arg_param" ] ; then
			s_arg="${s_arg//--mode=*/-m}"
			gas_result[$i_index]="$s_arg"
			gas_result[$(($i_index+1))]="$s_arg_param"
			let i_index=$(($i_index+2))
		else
			s_arg="${s_arg//--verbose/-v}"
			s_arg="${s_arg//--version/-V}"
			s_arg="${s_arg//--help/-h}"
			gas_result[$i_index]="$s_arg"
			let i_index=$(($i_index+1))
		fi
	done
}

#===  FUNCTION  ==============================================================
#          NAME:  main
#   DESCRIPTION:  メインの処理.
#    PARAMETERS:  $@: 本スクリプトに渡す引数. usage 関数を参照.
#       RETURNS:  プログラムの終了状態 { 0:正常終了, 1:引数指定エラー }
#=============================================================================
function main()
{
	local let i_mode_flag=0			# 実行モード { 0:反転, 1:有効化, 2:無効化, 3:状態 }
	local     s_device=''			# タッチパッドのデバイス名.
	local let i_now_status_flag=0	# 現在の状態フラグ. {0:無効, 1:有効}

	# コマンドライン・オプションの処理
	while getopts 'm:vVh' opt $@
	do
		case $opt in
		m )
			# 実行モード オプションの処理
			case "$OPTARG" in
			$DEF_OPT_MODE_TOGGLE)
				let i_mode_flag=0
				;;
			$DEF_OPT_MODE_ENABLE)
				let i_mode_flag=1
				;;
			$DEF_OPT_MODE_DISABLE)
				let i_mode_flag=2
				;;
			$DEF_OPT_MODE_STATUS)
				let i_mode_flag=3
				let gi_verbose_flag=1
				;;
			*)
				# 標準エラー出力へ警告、および簡易使用法を表示して終了
				message_output "コマンドライン・オプション -$opt の引数指定が間違っています. 正しい使用法は以下の通りです." 2
				usage 2
				return $DEF_EXIT_FAILURE
			esac    # --- end of case ---
			;;
		v )
			# 冗長な表示 オプションの処理
			let gi_verbose_flag=1
			;;
		V )
			# バージョンを表示して終了
			version 1
			return $DEF_EXIT_SUCCESS
			;;
		h )
			# 簡易使用法を表示して終了
			usage 1
			return $DEF_EXIT_SUCCESS
			;;
		* )
			# 標準エラー出力へ警告、および簡易使用法を表示して終了
			message_output "コマンドライン・オプションの指定が間違っています. 正しい使用法は以下の通りです." 2
			usage 2
			return $DEF_EXIT_FAILURE
		esac    # --- end of case ---
	done

	# 処理済みのコマンドライン・オプションを引数から破棄しておく
	shift $(($OPTIND-1))

	# 必要なコマンドが揃っているか確認
	exists_needed_commands
	if [ $? -eq $DEF_EXIT_FAILURE ] ; then
		return $DEF_EXIT_FAILURE
	fi

	# まずデバイス名と現在の状態を取得する
	get_touchpad_devicename_and_status
	if [ $? -eq $DEF_EXIT_FAILURE ] ; then
		return $DEF_EXIT_FAILURE
	fi
	s_device="$gs_result"
	let i_now_status_flag=$gi_result

	# 実行モードとして反転以外が指定されている場合は、それに従う
	if [ $i_mode_flag -eq 1 ] ; then
		touchpad_enable "$s_device"
		return $?
	elif [ $i_mode_flag -eq 2 ] ; then
		touchpad_disable "$s_device"
		return $?
	elif [ $i_mode_flag -eq 3 ] ; then
		return $DEF_EXIT_SUCCESS
	fi

	# 反転を実行
	toggle_touchpad "$s_device" "$i_now_status_flag"
	if [ $? -eq $DEF_EXIT_FAILURE ] ; then
		return $DEF_EXIT_FAILURE
	fi

	return $DEF_EXIT_SUCCESS
}

##############################################################################
# メイン処理                                                      Main Process
##############################################################################
# NOTE: コマンドライン・オプション、引数処理前に何か行いたい場合、ここに書く
#       シグナルをトラップする場合もここに書く

translate_long_options "$@"
main "${gas_result[@]}"

# vim:set ts=4 tw=0 ff=unix ft=sh : This is vim modeline #

