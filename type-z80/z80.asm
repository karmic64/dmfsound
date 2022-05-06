.memorymap
defaultslot 0
slotsize $2000
slot 0 $0000
.endme

.rombankmap
bankstotal 1
banksize $2000
banks 1
.endro


.define FM1REG $4000
.define FM1DATA $4001
.define FM2REG $4002
.define FM2DATA $4003

.define BANK $6000

.define PSG $7f11



;;;;;;;;;;;;;;;;; player-related constants

.include "KN-MODULE-CONSTANTS.asm"

	
.define KN_CHANNELS 14

.define KN_SONG_SLOT_TRACKS 13

.define KN_TRACKS KN_SONG_SLOTS*KN_SONG_SLOT_TRACKS



;;;;;;;;;;;;;;;; ram structures

	;;; macro
.enum 0
mac_base dsb 3
mac_index db
mac_size .db
.ende


	;;; fm patch
.enum 0
fm_30 dsb 4
fm_40 dsb 4
fm_50 dsb 4
fm_60 dsb 4
fm_70 dsb 4
fm_80 dsb 4
fm_90 dsb 4
fm_b0 db
fm_b4 db
fm_size .db
.ende


	;;; track
.enum 8 desc
T_FLG_ON db
T_FLG_CUT db
T_FLG_KEYOFF db
T_FLG_NOTE_RESET db
T_FLG_FM_UPDATE db
.ende


	;;; this is indexed from -$80 to allow the full (ix+$xx) addressing mode range
.enum -$80
t_flags dsb 1
t_chn dsb 1

t_seq_base dsb 3
t_patt_ptr dsb 3

t_dur_cnt dsb 1
t_dur_save dsb 1

t_delay dsb 1
t_legato dsb 1
t_cut dsb 1
t_smpl_bank dsb 1
t_retrig dsb 1
t_retrig_cnt dsb 1
t_note dsb 1

;;;
t_instr dsw 1

t_vol dsw 1 ;this is a word because volume slide needs a fractional part- most routines should only access the upper byte
t_vol_slide dsb 1
t_pan dsb 1

t_pitch dsw 1
t_slide dsw 1
t_slide_target dsb 1
t_finetune dsb 1

t_arp dsb 1
t_arp_speed dsb 1
t_arp_cnt dsb 1
t_arp_phase dsb 1

t_vib dsb 1
t_vib_phase dsb 1
t_vib_fine dsb 1
t_vib_mode dsb 1


;;;
t_fm dsb fm_size

t_macros dsb mac_size*MACRO_SLOTS

t_macro_vol dsb 1
t_macro_arp dsb 1

t_psg_noise dsb 1

t_dac_mode dsb 1

	;0: no sample
	;$02xxxxxx: sample map, xxxxxx is the pointer (TODO: NOT IMPLEMENTED)
	;$03xxxxxx: pitchable single sample, xxxxxx is the pointer
t_instr_sample dsb 3
t_instr_sample_type db



t_end_offs .db
.ende

.define t_size t_end_offs+$80




	;;; song slot
.define SS_FLG_ON 7
.define SS_FLG_LOOP 6

.define SS_FLG_LINEAR_PITCH 3
.define SS_FLG_CONT_VIB 2
.define SS_FLG_PT_SLIDE 1
.define SS_FLG_PT_ARP 0


.enum 0
ss_flags dsb 1
ss_volume dsb 1

ss_song_id dsw 1
	
ss_order dsb 1
ss_patt_break dsb 1 ;$ff - no skip
ss_song_size dsb 1

ss_speed_cnt dsb 1
ss_speed1 dsb 1
ss_speed2 dsb 1

ss_row dsw 1
ss_patt_size dsw 1

ss_sample_map dsb 3

ss_size .db
.ende





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; private variables
.enum $0c00 ;this may need to be increased in the future


k_temp dsb $10 ;general-purpose temporary storage
k_cur_track db
k_cur_track_ptr dw
k_cur_song_slot db
k_cur_song_slot_ptr dw


k_frame_cnt db
k_cur_frame db


k_comm_index db



k_song_slots dsb ss_size*KN_SONG_SLOTS
k_tracks_real dsb t_size*KN_TRACKS


k_chn_track dsb KN_CHANNELS

k_prv_fm_track dsb 10

k_psg_prv_noise dsb 1

k_fm_prv_chn3_keyon dsb 1
k_fm_extd_chn3 dsb 1
k_fm_lfo dsb 1

.ende


.define k_tracks k_tracks_real+$80






;;;;;;;;;;;;;;; effect enum
.enum $c0
EFF_PORTAUP db
EFF_PORTADOWN db
EFF_NOTEUP db
EFF_NOTEDOWN db
EFF_TONEPORTA db
EFF_ARP db
EFF_VIBRATO db
EFF_PANNING db
EFF_SPEED1 db
EFF_SPEED2 db
EFF_VOLSLIDE db
EFF_PATTBREAK db
EFF_RETRIG db

EFF_ARPTICK db
EFF_VIBMODE db
EFF_VIBDEPTH db
EFF_FINETUNE db
EFF_LEGATO db
EFF_SMPLBANK db
EFF_CUT db
EFF_SYNC db

EFF_LFO db
EFF_FB db
EFF_TL1 db
EFF_TL2 db
EFF_TL3 db
EFF_TL4 db
EFF_MUL db
EFF_DAC db
EFF_AR1 db
EFF_AR2 db
EFF_AR3 db
EFF_AR4 db
EFF_AR db

EFF_NOISE db

EFF_SIZE .db
.ende


.define MAX_EFFECT EFF_SIZE-1




;;;;;;;;;;;;;;;; 68k-z80 communication variables

.define STACK_POINTER $1ed0
.enum STACK_POINTER
comm_end_index db
sync_flag db

;68k bus pointers
duration_tbl_base dsb 3
song_tbl_base dsb 3
instrument_tbl_base dsb 3
fm_tbl_base dsb 3
sample_map_tbl_base dsb 3
sample_tbl_base dsb 3

note_octave_tbl_base dsb 3
psg_period_tbl_base dsb 3
psg_volume_tbl_base dsb 3
vib_tbl_base dsb 3
fm_finetune_tbl_base dsb 3
psg_finetune_tbl_base dsb 3
semitune_tbl_base dsb 3
vib_scale_tbl_base dsb 3

.ende

.define comm_buf $1f00



;;;;;;;;;;;;;;;;; reset handler/rst routines/irq handler


	;reset stub
	.orga 0
	di
	im 1
	ld sp,STACK_POINTER
	jr reset
	
	
	;read byte from banked pointer chl into a then step pointer
	.orga 8
get_byte:
	ld a,(hl)
	inc l
	ret nz
	inc h
	ret nz
	ld h,$80
	inc c
	;now we are at $10, another good rst location
	;sets bank to c
set_bank:
	push af
	push hl
	ld hl,BANK
	ld a,c
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	ld (hl),0
	pop hl
	pop af
	ret
	
	
	
	;;;;;;;;;;;;;;;;;;;;;; irq
	.orga $38
	push af
	push hl
	
	ld hl,k_frame_cnt
	inc (hl)
	
	;wait until irq is unasserted
	ld hl,$7f08
	ld a,$e1
-:	cp (hl)
	jr nc,-
	
	pop hl
	pop af
	
	ei
	ret
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;; reset
	
reset:
	
	;kill psg
	ld hl,PSG
	ld (hl),$9f
	ld (hl),$bf
	ld (hl),$df
	ld (hl),$ff
	
	
	;music ram was already zeroed out by the 68k, so we only need to init nonzero vars
	
	ld a,$ff
	ld b,10
	ld hl,k_prv_fm_track
-:	ld (hl),a
	inc hl
	djnz -
	
	
	ld iy,k_song_slots
	ld b,KN_SONG_SLOTS
	ld de,ss_size
-:	ld (iy+ss_song_id),a
	ld (iy+ss_song_id+1),a
	ld (iy+ss_patt_break),a
	add iy,de
	djnz -
	
	
	ld a,2
	ld (k_fm_prv_chn3_keyon),a
	
	ld a,8
	ld (k_fm_lfo),a
	
	
	ei
	
	
	
	
	
return_main_loop:
	;;; wait for next frame
	ld ix,k_frame_cnt
	
	ld a,(ix+1)
-:	cp (ix+0)
	jr z,-
	
	inc (ix+1)
	
	
	;;; handle 68k commands
	
	ld h,>comm_buf
	ld a,(k_comm_index)
	ld l,a
	ld a,(comm_end_index)
	cp l
	jr z,@no_command
	ld b,a
	
@command_loop:
	ld ix,@command_tbl
	ld e,(hl)
	inc l
	ld d,0
	add ix,de
	ld de,@next_command
	push de
	jp (ix)
	
@command_tbl:
	jr @cmd_init
	jr @cmd_volume
	jr @cmd_seek
	jr @cmd_pause
	jr @cmd_resume
	jr @cmd_stop
	
@get_song_slot:
	ld a,(hl)
	inc l
	push hl
	call set_song_slot
	pop hl
	ret
	
@cmd_init:
	ld a,(hl)
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	inc l
	push bc
	push hl
	call kn_init
	pop hl
	pop bc
	ret
	
@cmd_volume:
	call @get_song_slot
	ld a,(hl)
	inc l
	ld (iy+ss_volume),a
	ret
	
@cmd_seek:
	call @get_song_slot
	ld a,(hl)
	inc l
	ld (iy+ss_patt_break),a
	ret
	
@cmd_pause:
	call @get_song_slot
	res SS_FLG_ON,(iy+ss_flags)
	ret
	
@cmd_resume:
	call @get_song_slot
	bit 7,(iy+ss_song_id+1)
	ret nz
	set SS_FLG_ON,(iy+ss_flags)
	ret
	
@cmd_stop:
	call @get_song_slot
	ld (iy+ss_flags),0
	ld a,$ff
	ld (iy+ss_song_id),a
	ld (iy+ss_song_id+1),a
	ret
	
	
@next_command:
	ld a,l
	cp b
	jr nz,@command_loop
	ld (k_comm_index),a
	
@no_command:
	
	
	
	
	
	;;; play music
	call kn_play
	
	
	jp return_main_loop
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;; misc routines
	
	;add de to banked pointer chl, then set the bank
step_ptr:
	add hl,de
	jr nc,+
	inc c
	ld de,$8000
	add hl,de
	jr nc,+
	inc c
	set 7,h
+:	jp set_bank
	
	
	
	
	;bc * de = dehl
mulu:
	ld hl,0
	jr muls@mulbpos+1
	
	;signed bc * de = dehl
muls:
  ld hl,0

  bit 7,d
  jr z,@muldpos
  sbc hl,bc
@muldpos:

  or b
  jp p,@mulbpos
  sbc hl,de
@mulbpos:

  ld a,16
  
@loop:
  add hl,hl
  rl e
  rl d
  jr nc,+
  add hl,bc
  jr nc,+
  inc de
+:
  dec a
  jr nz,@loop
  
  ret
	
	
	
	
	;read 68k pointer indirect from (banked ahl)+(de*4)+1
indexed_read_68k_ptr:
	ld c,a
	ex de,hl
	add hl,hl
	add hl,hl
	inc hl
	ex de,hl
	call step_ptr
	
	;read 68k pointer from banked pointer chl, convert into chl, then set bank
read_68k_ptr:
	rst get_byte
	ld b,a
	rst get_byte
	ld d,a
	rst get_byte
	ld l,a
	ld a,d
	rlca
	rl b
	set 7,d
	ld h,d
	ld c,b
	jp set_bank
	
	
	
	
	;id in a
set_track:
	ld (k_cur_track),a
	ld de,track_ptr_tbl
load_track_from_table:
	add a,a
	ld l,a
	ld h,0
	add hl,de
	ld a,(hl)
	ld ixl,a
	inc hl
	ld a,(hl)
	ld ixh,a
	ld (k_cur_track_ptr),ix
	ret
	
	
	;id in a
set_song_slot:
	ld (k_cur_song_slot),a
	ld de,song_slot_ptr_tbl
load_song_slot_from_table:
	add a,a
	ld l,a
	ld h,0
	add hl,de
	ld a,(hl)
	ld iyl,a
	inc hl
	ld a,(hl)
	ld iyh,a
	ld (k_cur_song_slot_ptr),iy
	ret
	
	
	
	
	;id in variable
get_track_song_slot:
	ld a,(k_cur_track)
	ld de,kn_track_song_slot_ptr_tbl
	jr load_song_slot_from_table
	
	
	;id in variable
get_song_slot_track:
	ld a,(k_cur_song_slot)
	ld de,kn_song_slot_track_ptr_tbl
	jr load_track_from_table
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; init routine
	; song slot in a, song id in de (loop flag in bit 15)
kn_init:
	;;;; get track and song slot
	exx
	call set_song_slot
	call get_song_slot_track
	exx
	
	;;;; set song id in slot
	push de
	res 7,d
	ld (iy+ss_song_id),e
	ld (iy+ss_song_id+1),d
	
	;;;; get song base
	ld hl,(song_tbl_base)
	ld a,(song_tbl_base+2)
	call indexed_read_68k_ptr
	
	;;;; setup song slot
	rst get_byte ;flags
	pop de
	bit 7,d
	jr z,+
	set SS_FLG_LOOP,a
+:	ld (iy+ss_flags),a
	
	rst get_byte ;speeds
	ld (iy+ss_speed1),a
	rst get_byte
	ld (iy+ss_speed2),a
	dec a
	ld (iy+ss_speed_cnt),a
	
	rst get_byte ;pattern size
	rst get_byte
	ld (iy+ss_patt_size+1),a
	rst get_byte
	ld (iy+ss_patt_size),a
	
	rst get_byte ;sample map
	ld d,a
	rst get_byte
	ld e,a
	push bc
	push hl
	ld hl,(sample_map_tbl_base)
	ld a,(sample_map_tbl_base+2)
	call indexed_read_68k_ptr
	ld (iy+ss_sample_map),l
	ld (iy+ss_sample_map+1),h
	ld (iy+ss_sample_map+2),c
	pop hl
	pop bc
	rst set_bank
	
	rst get_byte ;song size
	ld (iy+ss_song_size),a
	
	ld (iy+ss_order),0 ;misc init
	ld a,$ff
	ld (iy+ss_volume),a
	ld (iy+ss_row),a
	ld (iy+ss_row+1),a
	ld (iy+ss_patt_break),a
	
	
	;;;; set up tracks
	rst get_byte ;channel count
	push af
	ld (k_temp),a
	
	;get the start address of the sequence (currently we point to the channel arrangement)
	push bc
	push hl
	
	;if the amount of channels is odd, realign the chn.arr. step count
	ld e,a
	ld d,0
	
	rrca
	jr nc,+
	inc e
+:	
	
	;step to sequence
	call step_ptr
	ld (k_temp+2),hl
	ld a,c
	ld (k_temp+4),a
	
	;get sequence size (song size * 4)
	ld l,(iy+ss_song_size)
	ld h,0
	add hl,hl
	add hl,hl
	ld (k_temp+5),hl
	
	pop hl ;get pointer to channel arrangement back
	pop bc
	rst set_bank
	
	
	;;; main track init loop
@track_init_loop:

	;; first, clear variables
	ld a,ixl ;adjust pointer back -$80
	sub $80
	ld e,a
	ld a,ixh
	sbc 0
	ld d,a
	ld b,t_size
	xor a
-:	ld (de),a
	inc de
	djnz -
	
	
	;; init pattern player
	ld (ix+t_flags), (1 << T_FLG_ON) | (1 << T_FLG_CUT) | (1 << T_FLG_KEYOFF) | (1 << T_FLG_FM_UPDATE)
	rst get_byte
	ld (ix+t_chn),a
	
	push bc ;get sequence base
	push hl
	ld hl,(k_temp+2)
	ld a,(k_temp+4)
	ld (ix+t_seq_base),l
	ld (ix+t_seq_base+1),h
	ld (ix+t_seq_base+2),a
	ex de,hl ;now step
	ld hl,(k_temp+5)
	ex de,hl
	call step_ptr
	ld (k_temp+2),hl
	ld a,c
	ld (k_temp+4),a
	pop hl
	pop bc
	rst set_bank
	
	inc (ix+t_dur_cnt)
	
	;; init instruments/effects
	dec (ix+t_instr)
	dec (ix+t_instr+1)
	dec (ix+t_slide_target)
	ld (ix+t_pan),$c0
	inc (ix+t_arp_speed)
	ld (ix+t_vib_fine),$0f
	
	ld (ix+t_psg_noise),3
	
	;initialize fm patch to TL $7f/RR $f/ D1L $f
	;this is to avoid any init noise
	dec (ix+t_fm+fm_40)
	dec (ix+t_fm+fm_40+1)
	dec (ix+t_fm+fm_40+2)
	dec (ix+t_fm+fm_40+3)
	dec (ix+t_fm+fm_80)
	dec (ix+t_fm+fm_80+1)
	dec (ix+t_fm+fm_80+2)
	dec (ix+t_fm+fm_80+3)
	
	;depending on channel type, init volume
	ld b,$7f
	ld a,(ix+t_chn)
	cp 6+4
	jr c,+
	ld b,$0f
+:	ld (ix+t_vol),b
	
	
	
	;; next
	ld de,t_size
	add ix,de
	
	ld a,(k_temp)
	dec a
	ld (k_temp),a
	jp nz,@track_init_loop
	
	
	
	
	
	
	;;;; turn off any unused tracks
	pop bc ;pop channel count back off (in b)
	ld a,KN_SONG_SLOT_TRACKS
	sub b
	ret z
	
	ld de,t_size
	ld b,a
-:	ld (ix+t_flags),0
	add ix,de
	djnz -
	
	
	ret
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; play routine
	
kn_play:
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle song slots
	ld a,KN_SONG_SLOTS-1
	ld iy,k_song_slots + (ss_size*(KN_SONG_SLOTS-1))
@song_slot_loop:
	ld (k_cur_song_slot),a
	
	bit SS_FLG_ON,(iy+ss_flags)
	jp z,@@next_song_slot
	
	;;is the row over?
	
	;get row speed in (hl)
	ld d,iyh
	ld e,iyl
	ld hl,ss_speed1
	add hl,de
	bit 0,(iy+ss_row)
	jr z,+
	inc hl
+:	;if speedcnt+=1 >= speed, row is over
	ld a,(iy+ss_speed_cnt)
	inc a
	cp (hl)
	jp c,@@no_next_row
	ld (iy+ss_speed_cnt),0
	
	
	;; row is over, check for a pattern break
	ld a,(iy+ss_patt_break)
	cp $ff
	jr z,@@no_patt_break
	
	ld (iy+ss_patt_break),$ff
	jr @@song_set_order
	
@@no_patt_break:
	;; no pattern break, check for the end of the pattern
	;; when row+=1 >= patt size
	ld l,(iy+ss_row)
	ld h,(iy+ss_row+1)
	inc hl
	ld a,l
	cp (iy+ss_patt_size)
	ld a,h
	sbc (iy+ss_patt_size+1)
	jr c,@@no_next_pattern
	
	ld a,(iy+ss_order)
	inc a
	cp (iy+ss_song_size) ;song over?
	jr c,@@song_set_order
	xor a
	
@@song_set_order:
	;right now the new order number is in A
	ld (iy+ss_row),0
	ld (iy+ss_row+1),0
	
	;put the result of comparing old order - new order in the upper bit of c
	ld c,a
	ld a,(iy+ss_order)
	cp c
	ld (iy+ss_order),c ;then save it
	rr c
	
	
	;;prepare all tracks for the next pattern
	call get_song_slot_track
	ld b,KN_SONG_SLOT_TRACKS
@@track_reset_loop:
	bit T_FLG_ON,(ix+t_flags)
	jr z,@@next_track_reset
	
	;on z80, the pattern reader itself resets the pattern index
	ld (ix+t_dur_cnt),1
	
	;we need to do loop detection.
	;a loop is defined when the new order <= old order
	;this bit is set when there is a carry from old order - new order
	;or, if old order < new order
	bit 7,c
	jr nz,@@next_track_reset ;old < new, this is not a loop
	
	;if we should not loop, stop the entire song
	bit SS_FLG_LOOP,(iy+ss_flags)
	jr nz,@@yes_loop
	xor a
	ld (iy+ss_flags),a
	dec a
	ld (iy+ss_song_id),a
	ld (iy+ss_song_id+1),a
	jr @@next_song_slot
	
	
@@yes_loop:
	;dumb way to not have to save the song state on loop
	set T_FLG_CUT,(ix+t_flags)
	xor a
	ld (ix+t_slide),a
	ld (ix+t_slide+1),a
	ld (ix+t_vol_slide),a
	
	ld d,$7f
	ld a,(ix+t_chn)
	cp 6+4
	jr c,+
	ld d,$0f
+:	ld (ix+t_vol),d
	
	
	
@@next_track_reset:
	ld de,t_size
	add ix,de
	djnz @@track_reset_loop
	
	
	
	
	jr @@next_song_slot
	
	
@@no_next_pattern:
	ld (iy+ss_row),l
	ld (iy+ss_row+1),h
	jr @@next_song_slot
	
@@no_next_row:
	ld (iy+ss_speed_cnt),a
	
@@next_song_slot:
	ld de,-ss_size
	add iy,de
	
	ld a,(k_cur_song_slot)
	dec a
	jp p,@song_slot_loop
	
	
	
	
	
	ret
	
	
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; data
	
track_ptr_tbl:
	.redefine idx 0
	.rept KN_TRACKS
		.dw t_size*idx + k_tracks
		.redefine idx idx+1
	.endr
	
song_slot_ptr_tbl:
	.redefine idx 0
	.rept KN_SONG_SLOTS
		.dw ss_size*idx + k_song_slots
		.redefine idx idx+1
	.endr
	
	

kn_track_song_slot_ptr_tbl:
	.redefine idx 0
	.rept KN_SONG_SLOTS
		.dsw KN_SONG_SLOT_TRACKS, ss_size*idx + k_song_slots
		.redefine idx idx+1
	.endr

kn_song_slot_track_ptr_tbl:
	.redefine idx 0
	.rept KN_SONG_SLOTS
		.dw t_size*idx*KN_SONG_SLOT_TRACKS + k_tracks
		.redefine idx idx+1
	.endr
	
kn_song_slot_size_tbl:
	.dsb KN_SONG_SLOTS,KN_SONG_SLOT_TRACKS
	
	
	
	
fm_chn3_freq_reg_tbl:
	.db $ad,$ac,$ae,$a6
	
.define C_FNUM 644
fm_fnum_tbl:
	.dw 644,681,722,765,810,858,910,964,1021,1081,1146,1214
	
	
	
	
	
	
	
	
	
	