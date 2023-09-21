* cut - cut out fields from line
*
* Itagaki Fumihiko 29-Sep-93  Create.
* Itagaki Fumihiko 26-Dec-93  Brush Up.
* Itagaki Fumihiko 02-Jan-94  入力行の長さやフィールド数の制限を無くした
* 1.0
* Itagaki Fumihiko 01-Jun-95  -f で、2バイト文字以降の 1バイト文字のデリミタが認識されない
*                             不具合を修正
* 1.1
*
* Usage: cut -b <リスト> [ -nBCZ ] [ -- ] [ <ファイル> ] ...
*        cut -c <リスト> [ -BCZ ] [--] [ <ファイル> ] ...
*        cut -f <リスト> [ -d <デリミタ> ] [ -sBCZ ] [ -- ] [ <ファイル> ] ...

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref issjis
.xref atou
.xref strlen
.xref strcmp
.xref strfor1
.xref memmovi
.xref memmovd
.xref strip_excessive_slashes

STACKSIZE	equ	2048

READ_MAX_TO_OUTPUT_TO_COOKED	equ	8192
INPBUFSIZE_MIN	equ	258
OUTBUF_SIZE	equ	8192

CTRLD	equ	$04
CTRLZ	equ	$1A

FLAG_n		equ	0	*  -n
FLAG_s		equ	1	*  -s
FLAG_B		equ	2	*  -B
FLAG_C		equ	3	*  -C
FLAG_Z		equ	4	*  -Z
FLAG_eof	equ	5

UNIT_b		equ	0	*  byte
UNIT_c		equ	1	*  character
UNIT_f		equ	2	*  field


.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bss_top(pc),a6
		lea	stack_bottom(a6),a7		*  A7 := スタックの底
		lea	$10(a0),a0			*  A0 : PDBアドレス
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
		move.l	#-1,stdin(a6)
	*
	*  引数並び格納エリアを確保する
	*
		lea	1(a2),a0			*  A0 := コマンドラインの文字列の先頭アドレス
		bsr	strlen				*  D0.L := コマンドラインの文字列の長さ
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := 引数並び格納エリアの先頭アドレス
	*
	*  引数をデコードし，解釈する
	*
		moveq	#0,d6				*  D6.W : エラー・コード
		bsr	DecodeHUPAIR			*  引数をデコードする
		movea.l	a1,a0				*  A0 : 引数ポインタ
		move.l	d0,d7				*  D7.L : 引数カウンタ
		subq.l	#1,d0
		bne	decode_opt_start

		lea	word_let(pc),a1
		lea	msg_let(pc),a2
		bsr	strcmp
		beq	joke

		lea	word_purse(pc),a1
		lea	msg_purse(pc),a2
		bsr	strcmp
		beq	joke

		lea	word_throat(pc),a1
		lea	msg_throat(pc),a2
		bsr	strcmp
		beq	joke

		lea	word_up(pc),a1
		lea	msg_up(pc),a2
		bsr	strcmp
		beq	joke

		lea	word_worm(pc),a1
		lea	msg_worm(pc),a2
		bsr	strcmp
		beq	joke
decode_opt_start:
		*  とりあえず field list に最大メモリを割り当てておく
		move.l	#$00ffffff,d0
		bsr	malloc
		sub.l	#$81000000,d0
		move.l	d0,d3				*  D3.L : field list の容量
		cmp.l	#4,d3
		blo	insufficient_memory

		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,list_top(a6)
		movea.l	d0,a1
		clr.l	(a1)
		moveq	#4,d4				*  D4.L : field list 使用バイト数
		moveq	#0,d5				*  D5.L : フラグ
		move.b	#-1,unit(a6)
		move.w	#HT,delimiter(a6)
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		tst.b	1(a0)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	decode_opt_done

		subq.l	#1,a0
decode_opt_loop2:
		moveq	#UNIT_b,d1
		cmp.b	#'b',d0
		beq	parse_list

		moveq	#UNIT_c,d1
		cmp.b	#'c',d0
		beq	parse_list

		moveq	#UNIT_f,d1
		cmp.b	#'f',d0
		beq	parse_list

		cmp.b	#'d',d0
		beq	parse_delimiter

		moveq	#FLAG_s,d1
		cmp.b	#'s',d0
		beq	set_option

		moveq	#FLAG_n,d1
		cmp.b	#'n',d0
		beq	set_option

		cmp.b	#'B',d0
		beq	option_B_found

		cmp.b	#'C',d0
		beq	option_C_found

		moveq	#FLAG_Z,d1
		cmp.b	#'Z',d0
		beq	set_option

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program

parse_list:
		tst.b	unit(a6)
		bpl	needs_one_of_bcf

		move.b	d1,unit(a6)

		tst.b	(a0)
		bne	parse_list_loop

		subq.l	#1,d7
		bcs	needs_list

		addq.l	#1,a0
parse_list_loop:
		move.b	(a0)+,d0
		beq	decode_opt_loop1

		cmp.b	#',',d0
		beq	parse_list_loop

		subq.l	#1,a0
		moveq	#1,d1
		bsr	list_atou
		bmi	bad_list
		bne	parse_list_1

		move.l	d0,d1
		cmpi.b	#'-',(a0)
		bne	parse_list_2			*  D0 == D1
parse_list_1:
		*  ここで
		*  D1.L : from
		cmpi.b	#'-',(a0)+
		bne	bad_list

		bsr	list_atou
		bmi	bad_list
		beq	parse_list_2

		moveq	#-1,d0				*  MAX
parse_list_2:
		exg	d0,d1
		*  ここで
		*  D0.L : from
		*  D1.L : to
		cmp.l	d0,d1
		blo	bad_list

		movea.l	list_top(a6),a1
parse_list_find_ins_point:
		tst.l	(a1)
		beq	ins_list_bottom

		cmp.l	4(a1),d0
		bls	ins_list_x

		addq.l	#8,a1
		bra	parse_list_find_ins_point

ins_list_bottom:
		*  D0-D1 をstoreする
		addq.l	#8,d4
		cmp.l	d4,d3
		blo	insufficient_memory

		move.l	d0,(a1)+
		move.l	d1,(a1)+
		clr.l	(a1)
		bra	parse_list_loop

ins_list_x:
		*  from <= 4(A1)
		cmp.l	(a1),d1
		blo	ins_list_less_than

		*  0(A1) <= to
		cmp.l	(a1),d0
		bhs	ins_list_x_from_ok

		*  from < 0(A1)
		move.l	d0,(a1)
ins_list_x_from_ok:
		*  0(A1) <= from <= 4(A1)
		cmp.l	4(a1),d1
		bls	parse_list_loop

		*  0(A1) <= from <= 4(A1) < to
		lea	8(a1),a2
ins_list_x_forward:
		tst.l	(a2)
		beq	ins_list_x_forward_shrink

		cmp.l	(a2),d1
		blo	ins_list_x_forward_shrink

		cmp.l	4(a2),d1
		bls	ins_list_x_forward_merge

		addq.l	#8,a2
		bra	ins_list_x_forward

ins_list_x_forward_merge:
		move.l	4(a2),d1
		addq.l	#8,a2
ins_list_x_forward_shrink:
		move.l	d1,4(a1)
		addq.l	#8,a1
		cmpa.l	a1,a2
		beq	ins_list_shrink_done
ins_list_x_forward_shrink_loop:
		move.l	(a2)+,(a1)+
		bne	ins_list_x_forward_shrink_loop
ins_list_shrink_done:
		move.l	a1,d4
		sub.l	list_top(a6),d4
		bra	parse_list_loop

ins_list_less_than:
		*  to < 0(A1)
		addq.l	#8,d4
		cmp.l	d4,d3
		blo	insufficient_memory

		movem.l	d0/a0,-(a7)
		movea.l	list_top(a6),a0
		adda.l	d4,a0
		move.l	a0,d0
		subq.l	#8,d0
		sub.l	a1,d0
		lea	-8(a0),a1
		bsr	memmovd
		movem.l	(a7)+,d0/a0
		move.l	d0,(a1)+
		move.l	d1,(a1)
		bra	parse_list_loop

bad_list:
		lea	msg_bad_list(pc),a0
werror_usage:
		bsr	werror_myname_and_msg
		bra	usage

needs_one_of_bcf:
		lea	msg_needs_one_of_bcf(pc),a0
		bra	werror_usage

needs_list:
		lea	msg_needs_list(pc),a0
		bra	werror_usage

needs_delimiter:
		lea	msg_needs_delimiter(pc),a0
		bra	werror_usage

bad_delimiter:
		lea	msg_bad_delimiter(pc),a0
		bra	werror_usage

parse_delimiter:
		tst.b	(a0)
		bne	parse_delimiter_0

		subq.l	#1,d7
		bcs	needs_delimiter

		addq.l	#1,a0
parse_delimiter_0:
		moveq	#0,d0
		move.b	(a0)+,d0
		bsr	issjis
		bne	parse_delimiter_1

		lsl.w	#8,d0
		move.b	(a0)+,d0
		beq	bad_delimiter
parse_delimiter_1:
		move.w	d0,delimiter(a6)
		tst.b	(a0)+
		bne	bad_delimiter
		bra	decode_opt_loop1

option_B_found:
		bclr	#FLAG_C,d5
		bset	#FLAG_B,d5
		bra	set_option_done

option_C_found:
		bclr	#FLAG_B,d5
		bset	#FLAG_C,d5
		bra	set_option_done

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		tst.b	unit(a6)
		bmi	needs_one_of_bcf

		*  field list を切り詰める
		move.l	d4,-(a7)
		move.l	list_top(a6),-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7

		moveq	#1,d0				*  出力は
		bsr	is_chrdev			*  キャラクタ・デバイスか？
		seq	do_buffering(a6)
		beq	input_max			*  -- block device

		*  character device
		btst	#5,d0				*  '0':cooked  '1':raw
		bne	input_max

		*  cooked character device
		move.l	#READ_MAX_TO_OUTPUT_TO_COOKED,d0
		btst	#FLAG_B,d5
		bne	inpbufsize_ok

		bset	#FLAG_C,d5			*  改行を変換する
		bra	inpbufsize_ok

input_max:
		move.l	#$00ffffff,d0
inpbufsize_ok:
		move.l	d0,read_size(a6)
		*  出力バッファを確保する
		tst.b	do_buffering(a6)
		beq	outbuf_ok

		move.l	#OUTBUF_SIZE,d0
		move.l	d0,outbuf_free(a6)
		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,outbuf_top(a6)
		move.l	d0,outbuf_ptr(a6)
outbuf_ok:
		*  入力バッファを確保する
		move.l	#$00ffffff,d0
		bsr	malloc
		sub.l	#$81000000,d0
		cmp.l	#INPBUFSIZE_MIN,d0
		blo	insufficient_memory

		move.l	d0,inpbuf_size(a6)
		bsr	malloc
		bmi	insufficient_memory
inpbuf_ok:
		move.l	d0,inpbuf_top(a6)
	*
	*  標準入力を切り替える
	*
		clr.w	-(a7)				*  標準入力を
		DOS	_DUP				*  複製したハンドルから入力し，
		addq.l	#2,a7
		move.l	d0,stdin(a6)
		bmi	start_do_files

		clr.w	-(a7)
		DOS	_CLOSE				*  標準入力はクローズする．
		addq.l	#2,a7				*  こうしないと ^C や ^S が効かない
start_do_files:
	*
	*  開始
	*
		tst.l	d7
		beq	do_stdin
for_file_loop:
		subq.l	#1,d7
		movea.l	a0,a1
		bsr	strfor1
		exg	a0,a1
		cmpi.b	#'-',(a0)
		bne	do_file

		tst.b	1(a0)
		bne	do_file
do_stdin:
		lea	msg_stdin(pc),a0
		move.l	stdin(a6),d0
		bmi	open_file_failure

		bsr	cut_one
		bra	for_file_continue

do_file:
		bsr	strip_excessive_slashes
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		tst.l	d0
		bmi	open_file_failure

		bsr	cut_one
		move.w	input_handle(a6),-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
for_file_continue:
		movea.l	a1,a0
		tst.l	d7
		bne	for_file_loop

		bsr	flush_outbuf
exit_program:
		move.l	stdin(a6),d0
		bmi	exit_program_1

		clr.w	-(a7)				*  標準入力を
		move.w	d0,-(a7)			*  元に
		DOS	_DUP2				*  戻す．
		DOS	_CLOSE				*  複製はクローズする．
exit_program_1:
		move.w	d6,-(a7)
		DOS	_EXIT2

open_file_failure:
		bsr	werror_myname_and_msg
		lea	msg_open_fail(pc),a0
		bsr	werror
		moveq	#2,d6
		bra	for_file_continue

joke:
		move.l	a2,-(a7)
		DOS	_PRINT
		addq.l	#4,a7
		bra	exit_program_1
****************************************************************
* cut_one
****************************************************************
cut_one:
		move.w	d0,input_handle(a6)
		btst	#FLAG_Z,d5
		sne	terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		bsr	is_chrdev
		beq	cut_one_start			*  -- ブロック・デバイス

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	cut_one_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
cut_one_start:
		bclr	#FLAG_eof,d5
		move.l	inpbuf_top(a6),inpbuf_ptr(a6)
		clr.l	inpbuf_remain(a6)
cut_one_loop:
		movea.l	list_top(a6),a3
		moveq	#0,d3				*  D3.L : fieldno counter
		move.b	unit(a6),d0
		beq	cut_byte

		subq.b	#1,d0
		beq	cut_char
****************
cut_field:
		clr.l	saved_count(a6)
		bsr	getc
		bmi	cut_one_done
cut_field_getline_loop:
		cmp.b	#LF,d0
		beq	cut_field_getline_ok

		bsr	getc
		bpl	cut_field_getline_loop
cut_field_getline_ok:
		movea.l	inpbuf_ptr(a6),a2
		move.l	saved_count(a6),d4
		suba.l	d4,a2
		move.l	a2,line_top(a6)
		sf	d1
cut_field_loop1:
		movea.l	a2,a4
cut_field_loop2:
		movea.l	a2,a5
		subq.l	#1,d4
		bcs	cut_field_last			*  D4.L == -1

		moveq	#0,d0
		move.b	(a2)+,d0
		cmp.b	#LF,d0
		beq	cut_field_lf

		cmp.b	#CR,d0
		beq	cut_field_cr

		bsr	issjis
		bne	cut_field_check_delimiter

		tst.l	d4
		beq	cut_field_check_delimiter

		movem.l	d0,-(a7)
		move.b	(a2),d0
		bsr	issjis2
		movem.l	(a7)+,d0
		bne	cut_field_check_delimiter

		subq.l	#1,d4
		lsl.w	#8,d0
		move.b	(a2)+,d0
cut_field_check_delimiter:
		cmp.w	delimiter(a6),d0
		bne	cut_field_loop2

		addq.l	#1,d3
		bsr	check_list
		beq	cut_field_skip_field

		bsr	cut_field_output_field_sub
		st	d1
		bra	cut_field_loop2

cut_field_skip_field:
		tst.b	d1
		beq	cut_field_loop1

		movea.l	a5,a4
		bra	cut_field_loop2

cut_field_cr:
		tst.l	d4
		beq	cut_field_loop2

		cmpi.b	#LF,(a2)
		bne	cut_field_loop2

		moveq	#1,d4				*  D4 := 1 : CRLF
		bra	cut_field_last

cut_field_lf:
		moveq	#0,d4				*  D4 := 0 : LF 
cut_field_last:
		tst.l	d3
		beq	cut_field_no_delimiter

		addq.l	#1,d3
		bcs	cut_field_output_newline

		bsr	check_list
		beq	cut_field_output_newline
		bra	cut_field_output_nl_field

cut_field_no_delimiter:
		btst	#FLAG_s,d5
		bne	cut_one_loop

		movea.l	line_top(a6),a4
cut_field_output_nl_field:
		bsr	cut_field_output_field_sub
cut_field_output_newline:
		tst.l	d4
		bmi	cut_one_loop
		bne	cut_one_crlf
		bra	cut_one_newline

cut_field_output_field_sub:
		cmpa.l	a5,a4
		beq	cut_field_output_field_sub_done

		move.b	(a4)+,d0
		bsr	putc
		bra	cut_field_output_field_sub

cut_field_output_field_sub_done:
cut_one_done:
		rts

cut_field_too_long_line:
		bsr	werror_myname_and_msg
		lea	msg_too_long_line,a0
		bsr	werror
		moveq	#2,d6
		bra	exit_program
****************
cut_byte:
cut_byte_loop:
		bsr	getc
cut_byte_loop_1:
		bmi	cut_one_done

		sf	d2
		cmp.b	#LF,d0
		beq	cut_one_newline

		cmp.b	#CR,d0
		bne	cut_byte_not_cr

		bsr	getc_next
		bmi	cut_byte_not_cr

		cmp.b	#LF,d1
		beq	cut_one_crlf
cut_byte_not_cr:
		tst.l	(a3)
		beq	cut_byte_continue

		addq.l	#1,d3
		tst.b	d2
		bne	cut_byte_not_sjis

		btst	#FLAG_n,d5
		beq	cut_byte_not_sjis

		bsr	issjis
		bne	cut_byte_not_sjis

		bsr	getc_next
		bmi	cut_byte_not_sjis

		exg	d0,d1
		bsr	issjis2
		exg	d0,d1
		bne	cut_byte_not_sjis

		sf	d2
		bsr	check_list
		beq	cut_byte_broken_sjis_1

		addq.l	#1,d3
		bsr	check_list
		beq	cut_byte_broken_sjis_2

		bsr	putc
		move.l	d1,d0
		bra	cut_byte_putc

cut_byte_broken_sjis_1:
		addq.l	#1,d3
		bsr	check_list
		beq	cut_byte_continue
cut_byte_broken_sjis_2:
		moveq	#' ',d0
		bra	cut_byte_putc

cut_byte_not_sjis:
		bsr	check_list
cut_byte_test:
		beq	cut_byte_continue
cut_byte_putc:
		bsr	putc
cut_byte_continue:
		tst.b	d2
		beq	cut_byte_loop

		move.l	d1,d0
		bra	cut_byte_loop_1
****************
cut_char:
cut_char_loop:
		bsr	getc
cut_char_loop_1:
		bmi	cut_one_done

		sf	d2
		cmp.b	#LF,d0
		beq	cut_one_newline

		cmp.b	#CR,d0
		bne	cut_char_not_cr

		bsr	getc_next
		bmi	cut_char_not_cr

		cmp.b	#LF,d1
		beq	cut_one_crlf
cut_char_not_cr:
		tst.l	(a3)
		beq	cut_char_continue

		tst.b	d2
		bne	cut_char_test

		moveq	#0,d1
		bsr	issjis
		bne	cut_char_test

		bsr	getc_next
		bmi	cut_char_test

		exg	d0,d1
		bsr	issjis2
		exg	d0,d1
		bne	cut_char_test

		sf	d2
cut_char_test:
		addq.l	#1,d3
		bsr	check_list
		beq	cut_char_continue
cut_char_putc:
		bsr	putc
		tst.b	d2
		bne	cut_char_continue_1

		move.l	d1,d0
		beq	cut_char_continue

		bsr	putc
cut_char_continue:
		tst.b	d2
		beq	cut_char_loop
cut_char_continue_1:
		move.l	d1,d0
		bra	cut_char_loop_1
****************
cut_one_newline:
		bsr	output_newline
		bra	cut_one_loop

cut_one_crlf:
		bsr	output_crlf
		bra	cut_one_loop
*****************************************************************
output_newline:
		btst	#FLAG_C,d5
		beq	output_lf
output_crlf:
		moveq	#CR,d0
		bsr	putc
output_lf:
		moveq	#LF,d0
		bra	putc
*****************************************************************
check_list:
		tst.l	(a3)
		beq	check_list_return		*  ZF == 1

		cmp.l	(a3),d3
		blo	check_list_out

		cmp.l	4(a3),d3
		bls	check_list_in

		addq.l	#8,a3
		bra	check_list

check_list_in:
		tst.l	d3				*  ZF := 0
		rts

check_list_out:
		cmp.w	d0,d0				*  ZF := 1
check_list_return:
		rts
*****************************************************************
getc_next:
		st	d2
		move.l	d0,d1
		bsr	getc
		exg	d0,d1
		rts
*****************************************************************
getc:
		movem.l	d3/a3,-(a7)
		movea.l	inpbuf_ptr(a6),a3
		move.l	inpbuf_remain(a6),d3
		bne	getc_get1

		btst	#FLAG_eof,d5
		bne	getc_eof

		move.l	inpbuf_top(a6),d0
		add.l	inpbuf_size(a6),d0
		sub.l	a3,d0
		bne	getc_read

		cmpi.b	#UNIT_f,unit(a6)
		bne	getc_new

		movem.l	a0-a1,-(a7)
		move.l	saved_count(a6),d0
		movea.l	a3,a1
		suba.l	d0,a1
		movea.l	inpbuf_top(a6),a0
		bsr	memmovi
		movea.l	a0,a3
		movem.l	(a7)+,a0-a1
		move.l	inpbuf_top(a6),d0
		add.l	inpbuf_size(a6),d0
		sub.l	a3,d0
		beq	insufficient_memory
		bra	getc_read

getc_new:
		movea.l	inpbuf_top(a6),a3
		move.l	inpbuf_size(a6),d0
getc_read:
		cmp.l	read_size(a6),d0
		bls	getc_read_1

		move.l	read_size(a6),d0
getc_read_1:
		move.l	d0,-(a7)
		move.l	a3,-(a7)
		move.w	input_handle(a6),-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail

		tst.b	terminate_by_ctrlz(a6)
		beq	trunc_ctrlz_done

		moveq	#CTRLZ,d0
		bsr	trunc
trunc_ctrlz_done:
		tst.b	terminate_by_ctrld(a6)
		beq	trunc_ctrld_done

		moveq	#CTRLD,d0
		bsr	trunc
trunc_ctrld_done:
		tst.l	d3
		beq	getc_eof
getc_get1:
		subq.l	#1,d3
		moveq	#0,d0
		move.b	(a3)+,d0
		addq.l	#1,saved_count(a6)
getc_done:
		move.l	a3,inpbuf_ptr(a6)
		move.l	d3,inpbuf_remain(a6)
		movem.l	(a7)+,d3/a3
		tst.l	d0
		rts

getc_eof:
		bset	#FLAG_eof,d5
		moveq	#-1,d0
		bra	getc_done

read_fail:
		bsr	werror_myname_and_msg
		lea	msg_read_fail(pc),a0
		bra	werror_exit_3
*****************************************************************
trunc:
		movem.l	d1/a0,-(a7)
		move.l	d3,d1
		beq	trunc_done

		movea.l	a3,a0
trunc_find_loop:
		cmp.b	(a0)+,d0
		beq	trunc_found

		subq.l	#1,d1
		bne	trunc_find_loop
		bra	trunc_done

trunc_found:
		move.l	a0,d3
		subq.l	#1,d3
		sub.l	a3,d3
		bset	#FLAG_eof,d5
trunc_done:
		movem.l	(a7)+,d1/a0
		rts
*****************************************************************
flush_outbuf:
		move.l	d0,-(a7)
		tst.b	do_buffering(a6)
		beq	flush_return

		move.l	#OUTBUF_SIZE,d0
		sub.l	outbuf_free(a6),d0
		beq	flush_return

		move.l	d0,-(a7)
		move.l	outbuf_top(a6),-(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_fail

		cmp.l	-4(a7),d0
		blo	write_fail

		move.l	outbuf_top(a6),d0
		move.l	d0,outbuf_ptr(a6)
		move.l	#OUTBUF_SIZE,d0
		move.l	d0,outbuf_free(a6)
flush_return:
		move.l	(a7)+,d0
		rts
*****************************************************************
putc:
		movem.l	d0/a0,-(a7)
		tst.b	do_buffering(a6)
		bne	putc_buffering

		move.w	d0,-(a7)
		move.l	#1,-(a7)
		pea	5(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	12(a7),a7
		cmp.l	#1,d0
		bne	write_fail
		bra	putc_done

putc_buffering:
		tst.l	outbuf_free(a6)
		bne	putc_buffering_1

		bsr	flush_outbuf
putc_buffering_1:
		movea.l	outbuf_ptr(a6),a0
		move.b	d0,(a0)+
		move.l	a0,outbuf_ptr(a6)
		subq.l	#1,outbuf_free(a6)
putc_done:
		movem.l	(a7)+,d0/a0
		rts
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bra	werror_exit_3
*****************************************************************
write_fail:
		lea	msg_write_fail(pc),a0
werror_exit_3:
		bsr	werror
		moveq	#3,d6
		bra	exit_program
*****************************************************************
werror_myname:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror_myname_and_msg:
		bsr	werror_myname
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
is_chrdev:
		move.w	d0,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		tst.l	d0
		bpl	is_chrdev_1

		moveq	#0,d0
is_chrdev_1:
		btst	#7,d0
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
list_atou:
		movem.l	d1,-(a7)
		bsr	atou
		neg.l	d0
		bne	list_atou_return		*  -1:overflow, 1:no digits

		move.l	d1,d0
		beq	list_atou_error

		moveq	#0,d1
list_atou_return:
		movem.l	(a7)+,d1
		rts

list_atou_error:
		moveq	#-1,d1
		bra	list_atou_return
*****************************************************************
issjis2:
		cmp.b	#$40,d0
		blo	return			* ZF=0

		cmp.b	#$7e,d0
		bls	true

		cmp.b	#$80,d0
		blo	return			* ZF=0

		cmp.b	#$fc,d0
		bhi	return			* ZF=0
true:
		cmp.b	d0,d0			* ZF=1
return:
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## cut 1.1 ##  Copyright(C)1994-95 by Itagaki Fumihiko',0

msg_myname:		dc.b	'cut: ',0
word_let:		dc.b	'-let',0
word_purse:		dc.b	'-purse',0
word_throat:		dc.b	'-throat',0
word_up:		dc.b	'-up',0
word_worm:		dc.b	'-worm',0
msg_no_memory:		dc.b	'メモリが足りません',CR,LF,0
msg_open_fail:		dc.b	': オープンできません',CR,LF,0
msg_read_fail:		dc.b	': 入力エラー',CR,LF,0
msg_write_fail:		dc.b	'cut: 出力エラー',CR,LF,0
msg_too_long_line:	dc.b	': 行が長すぎます',CR,LF,0
msg_stdin:		dc.b	'- 標準入力 -',0
msg_illegal_option:	dc.b	'不正なオプション -- ',0
msg_needs_one_of_bcf:	dc.b	'-b, -c, -f のどれかひとつを指定してください',0
msg_needs_list:		dc.b	'リストの指定がありません',0
msg_bad_list:		dc.b	'リストの指定が不正です',0
msg_needs_delimiter:	dc.b	'-d には <デリミタ> 引数が必要です',0
msg_bad_delimiter:	dc.b	'デリミタの指定が不正です',0
msg_usage:		dc.b	CR,LF
	dc.b	'使用法:  cut -b <リスト> [-nBCZ] [--] [<ファイル>] ...',CR,LF
	dc.b	'         cut -c <リスト> [-BCZ] [--] [<ファイル>] ...',CR,LF
	dc.b	'         cut -f <リスト> [-d <デリミタ>] [-sBCZ] [--] [<ファイル>] ...',CR,LF,0
msg_let:	dc.b	'cutlet n. カツレツ. 油で揚げたもの，あぶり焼きのもの, 衣をつけたもの, つけないものなどがある.',CR,LF,0
msg_purse:	dc.b	'cutpurse n. すり(pickpocket).',CR,LF,0
msg_throat:	dc.b	'cutthroat n. 人殺し(murder). ―a. 殺人の; 凶暴な(cruel); 激しい(keen), 破壊的な.',CR,LF,0
msg_up:		dc.b	'cutup n.【米俗】ふざけんぼう, 茶目; 自慢家.',CR,LF,0
msg_worm:	dc.b	'cutworm n. 根切り虫.',CR,LF,0
*****************************************************************
.bss
.even
bss_top:

.offset 0
stdin:			ds.l	1
inpbuf_top:		ds.l	1
inpbuf_size:		ds.l	1
inpbuf_ptr:		ds.l	1
inpbuf_remain:		ds.l	1
outbuf_top:		ds.l	1
outbuf_ptr:		ds.l	1
outbuf_free:		ds.l	1
read_size:		ds.l	1
saved_count:		ds.l	1
line_top:		ds.l	1
list_top:		ds.l	1
input_handle:		ds.w	1
delimiter:		ds.w	1
do_buffering:		ds.b	1
unit:			ds.b	1
terminate_by_ctrlz:	ds.b	1
terminate_by_ctrld:	ds.b	1

.even
			ds.b	STACKSIZE
.even
stack_bottom:

.bss
		ds.b	stack_bottom
*****************************************************************

.end start
