.data
    # --- FILE CONFIG ---
    input_filename:   .asciiz "input19-44-21_11-Nov-25_10_10_1.txt"
    desired_filename: .asciiz "desired19-44-21_11-Nov-25_10_10.txt"
    outFilename:      .asciiz "output.txt"

    # --- VARIABLES ---
    M:            .word 10            # M = 10
    N:            .word 10           # N = 10
    ten:          .float 10.0
    
    # --- HEAP POINTERS ---
    ptr_input:    .word 0
    ptr_desired:  .word 0
    ptr_output:   .word 0
    
    ptr_autocorr: .word 0
    ptr_vec_B:    .word 0
    ptr_coeffs:   .word 0
    ptr_matrix_A: .word 0
    
    # --- BUFFERS ---
    .align 2
    buffer:       .space 2048
    numBuffer:    .space 32
    
    mmse:         .float 0.0

    # --- STRINGS ---
    strMinus:     .asciiz "-"
    strDot:       .asciiz "."
    strSpace:     .asciiz " "
    strNewline:   .asciiz "\n"
    
    strFiltered:  .asciiz "Filtered output: "
    strMMSE:      .asciiz "\nMMSE: "
    errMsg:       .asciiz "Loi mo file.\n"

.text
.globl main

main:
    # ===========================================================
    # BƯỚC 0: CẤP PHÁT BỘ NHỚ
    # ===========================================================
    lw   $s0, M
    lw   $s1, N

    # Alloc Data Arrays
    sll  $a0, $s1, 2
    li   $v0, 9
    syscall
    sw   $v0, ptr_input
    
    li   $v0, 9
    syscall
    sw   $v0, ptr_desired
    
    li   $v0, 9
    syscall
    sw   $v0, ptr_output
    
    # Alloc Vectors
    sll  $a0, $s0, 2
    li   $v0, 9
    syscall
    sw   $v0, ptr_autocorr
    
    li   $v0, 9
    syscall
    sw   $v0, ptr_vec_B
    
    li   $v0, 9
    syscall
    sw   $v0, ptr_coeffs
    
    # Alloc Matrix
    mul  $t0, $s0, $s0
    sll  $a0, $t0, 2
    li   $v0, 9
    syscall
    sw   $v0, ptr_matrix_A
    

    # ===========================================================
    # PHẦN 1: ĐỌC FILE
    # ===========================================================
    li   $s7, 0

file_loop:
    beq  $s7, 2, process_phase
    beq  $s7, 1, set_des
    la   $a0, input_filename
    lw   $s2, ptr_input
    j    do_read
set_des:
    la   $a0, desired_filename
    lw   $s2, ptr_desired

do_read:
    li   $v0, 13
    li   $a1, 0
    li   $a2, 0
    syscall
    move $s0, $v0
    blt  $s0, 0, error_exit
    
    li   $v0, 14
    move $a0, $s0
    la   $a1, buffer
    li   $a2, 2048
    syscall
    
    li   $v0, 16
    move $a0, $s0
    syscall

    la   $s1, buffer
    li   $s3, 0
    lw   $s4, N
parse_L:
    beq  $s3, $s4, end_parse
skip_w:
    lb   $t0, 0($s1)
    beqz $t0, end_parse
    blt  $t0, 45, next_c
    li   $t1, 0
    li   $t2, 0
    li   $t3, 0
    li   $t4, 0
    bne  $t0, 45, r_int
    li   $t2, 1
    addi $s1, $s1, 1
    lb   $t0, 0($s1)
r_int:
    blt  $t0, 48, chk_dot
    bgt  $t0, 57, chk_dot
    mul  $t1, $t1, 10
    sub  $t0, $t0, 48
    add  $t1, $t1, $t0
    addi $s1, $s1, 1
    lb   $t0, 0($s1)
    j    r_int
chk_dot:
    bne  $t0, 46, do_cvt
    addi $s1, $s1, 1
    lb   $t0, 0($s1)
r_dec:
    blt  $t0, 48, do_cvt
    bgt  $t0, 57, do_cvt
    mul  $t3, $t3, 10
    sub  $t0, $t0, 48
    add  $t3, $t3, $t0
    addi $t4, $t4, 1
    addi $s1, $s1, 1
    lb   $t0, 0($s1)
    j    r_dec
do_cvt:
    mtc1 $t1, $f0
    cvt.s.w $f0, $f0
    mtc1 $t3, $f1
    cvt.s.w $f1, $f1
    l.s  $f2, ten
    l.s  $f3, ten
    li   $t5, 1
div_L:
    bge  $t5, $t4, combine
    mul.s $f3, $f3, $f2
    addi $t5, $t5, 1
    j    div_L
combine:
    beqz $t4, skip_div
    div.s $f1, $f1, $f3
skip_div:
    add.s $f0, $f0, $f1
    beqz $t2, save
    neg.s $f0, $f0
save:
    swc1 $f0, 0($s2)
    addi $s2, $s2, 4
    addi $s3, $s3, 1
    j    parse_L
next_c:
    addi $s1, $s1, 1
    j    skip_w
end_parse:
    addi $s7, $s7, 1
    j    file_loop

# ===========================================================
# PHẦN 2: TÍNH THỐNG KÊ (Autocorr & Crosscorr)
# ===========================================================
process_phase:
    lw   $s0, M
    lw   $s1, N
    
    li   $t0, 0
stat_outer:
    beq  $t0, $s0, build_matrix
    mtc1 $zero, $f4
    mtc1 $zero, $f5
    move $t1, $t0
stat_inner:
    beq  $t1, $s1, save_stats
    lw   $t2, ptr_input
    lw   $t3, ptr_desired
    sll  $t4, $t1, 2
    add  $t5, $t2, $t4
    lwc1 $f10, 0($t5)
    add  $t6, $t3, $t4
    lwc1 $f11, 0($t6)
    sub  $t7, $t1, $t0
    sll  $t7, $t7, 2
    add  $t8, $t2, $t7
    lwc1 $f12, 0($t8)
    mul.s $f20, $f10, $f12
    add.s $f4, $f4, $f20
    mul.s $f21, $f11, $f12
    add.s $f5, $f5, $f21
    addi $t1, $t1, 1
    j    stat_inner
save_stats:
    lw   $t2, ptr_autocorr
    sll  $t4, $t0, 2
    add  $t2, $t2, $t4
    swc1 $f4, 0($t2)
    lw   $t2, ptr_vec_B
    add  $t2, $t2, $t4
    swc1 $f5, 0($t2)
    addi $t0, $t0, 1
    j    stat_outer

build_matrix:
    li   $t0, 0
row_loop:
    beq  $t0, $s0, solve_gauss
    li   $t1, 0
col_loop:
    beq  $t1, $s0, next_row
    sub  $t2, $t0, $t1
    bgez $t2, get_lag
    sub  $t2, $zero, $t2
get_lag:
    lw   $t3, ptr_autocorr
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    lwc1 $f6, 0($t3)
    lw   $t3, ptr_matrix_A
    mul  $t4, $t0, $s0
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t3, $t3, $t4
    swc1 $f6, 0($t3)
    addi $t1, $t1, 1
    j    col_loop
next_row:
    addi $t0, $t0, 1
    j    row_loop

# ===========================================================
# PHẦN 3: GIẢI GAUSS
# ===========================================================
solve_gauss:
    li   $t0, 0
    addi $s1, $s0, -1
gauss_k:
    bge  $t0, $s1, back_sub
    addi $t1, $t0, 1
gauss_i:
    bge  $t1, $s0, next_k
    lw   $t3, ptr_matrix_A
    mul  $t2, $t1, $s0
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    add  $t4, $t3, $t2
    lwc1 $f8, 0($t4)
    mul  $t2, $t0, $s0
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    add  $t4, $t3, $t2
    lwc1 $f9, 0($t4)
    div.s $f10, $f8, $f9
    move $t2, $t0
gauss_j:
    bge  $t2, $s0, update_B
    lw   $t4, ptr_matrix_A
    mul  $t3, $t0, $s0
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t5, $t4, $t3
    lwc1 $f11, 0($t5)
    mul  $t3, $t1, $s0
    add  $t3, $t3, $t2
    sll  $t3, $t3, 2
    add  $t6, $t4, $t3
    lwc1 $f12, 0($t6)
    mul.s $f13, $f10, $f11
    sub.s $f12, $f12, $f13
    swc1  $f12, 0($t6)
    addi $t2, $t2, 1
    j    gauss_j
update_B:
    lw   $t3, ptr_vec_B
    sll  $t4, $t0, 2
    add  $t5, $t3, $t4
    lwc1 $f14, 0($t5)
    sll  $t4, $t1, 2
    add  $t5, $t3, $t4
    lwc1 $f15, 0($t5)
    mul.s $f13, $f10, $f14
    sub.s $f15, $f15, $f13
    swc1  $f15, 0($t5)
    addi $t1, $t1, 1
    j    gauss_i
next_k:
    addi $t0, $t0, 1
    j    gauss_k
back_sub:
    addi $t0, $s0, -1
back_i:
    blt  $t0, 0, do_filter
    lw   $t2, ptr_vec_B
    sll  $t3, $t0, 2
    add  $t2, $t2, $t3
    lwc1 $f20, 0($t2)
    addi $t1, $t0, 1
back_j:
    bge  $t1, $s0, calc_xi
    lw   $t3, ptr_matrix_A
    mul  $t2, $t0, $s0
    add  $t2, $t2, $t1
    sll  $t2, $t2, 2
    add  $t3, $t3, $t2
    lwc1 $f21, 0($t3)
    lw   $t3, ptr_coeffs
    sll  $t2, $t1, 2
    add  $t3, $t3, $t2
    lwc1 $f22, 0($t3)
    mul.s $f23, $f21, $f22
    sub.s $f20, $f20, $f23
    addi $t1, $t1, 1
    j    back_j
calc_xi:
    lw   $t3, ptr_matrix_A
    mul  $t2, $t0, $s0
    add  $t2, $t2, $t0
    sll  $t2, $t2, 2
    add  $t3, $t3, $t2
    lwc1 $f24, 0($t3)
    div.s $f25, $f20, $f24
    lw   $t3, ptr_coeffs
    sll  $t2, $t0, 2
    add  $t3, $t3, $t2
    swc1 $f25, 0($t3)
    addi $t0, $t0, -1
    j    back_i

# ===========================================================
# PHẦN 4: LỌC TÍN HIỆU
# ===========================================================
do_filter:
    lw   $s0, M
    lw   $s1, N
    li   $t0, 0
filt_loop:
    beq  $t0, $s1, calc_mmse
    mtc1 $zero, $f12
    li   $t1, 0
conv_loop:
    beq  $t1, $s0, save_y
    sub  $t2, $t0, $t1
    blt  $t2, 0, next_k_filt
    lw   $t3, ptr_coeffs
    sll  $t4, $t1, 2
    add  $t3, $t3, $t4
    lwc1 $f4, 0($t3)
    lw   $t3, ptr_input
    sll  $t4, $t2, 2
    add  $t3, $t3, $t4
    lwc1 $f5, 0($t3)
    mul.s $f6, $f4, $f5
    add.s $f12, $f12, $f6
next_k_filt:
    addi $t1, $t1, 1
    j    conv_loop
save_y:
    lw   $t3, ptr_output
    sll  $t4, $t0, 2
    add  $t3, $t3, $t4
    swc1 $f12, 0($t3)
    addi $t0, $t0, 1
    j    filt_loop

# ===========================================================
# PHẦN 5: TÍNH MMSE (CÔNG THỨC 2: Direct MSE)
# ===========================================================
calc_mmse:
    lw   $s3, ptr_desired
    lw   $s4, ptr_output
    lw   $s1, N
    li   $t0, 0
    mtc1 $zero, $f30
    cvt.s.w $f30, $f30
m_loop:
    beq  $t0, $s1, save_m
    sll  $t1, $t0, 2
    add  $t2, $s3, $t1
    lwc1 $f10, 0($t2)
    add  $t3, $s4, $t1
    lwc1 $f11, 0($t3)
    sub.s $f12, $f10, $f11
    mul.s $f12, $f12, $f12
    add.s $f30, $f30, $f12
    addi $t0, $t0, 1
    j    m_loop
save_m:
    mtc1  $s1, $f31
    cvt.s.w $f31, $f31
    div.s $f30, $f30, $f31
    la    $t0, mmse
    swc1  $f30, 0($t0)

    # ===========================================================
    # PHẦN 6: IN KẾT QUẢ
    # ===========================================================
    # Terminal
    li   $v0, 4
    la   $a0, strFiltered
    syscall
    lw   $s2, ptr_output
    li   $s3, 0
    lw   $s5, N
p_loop:
    beq  $s3, $s5, p_mmse
    lwc1 $f12, 0($s2)
    li   $v0, 2
    syscall
    li   $v0, 4
    la   $a0, strSpace
    syscall
    addi $s2, $s2, 4
    addi $s3, $s3, 1
    j    p_loop
p_mmse:
    li   $v0, 4
    la   $a0, strMMSE
    syscall
    mov.s $f12, $f30
    li   $v0, 2
    syscall
    li   $v0, 4
    la   $a0, strNewline
    syscall

    # File Output
    li   $v0, 13
    la   $a0, outFilename
    li   $a1, 1
    li   $a2, 0
    syscall
    move $s6, $v0
    blt  $s6, 0, error_exit
    li   $v0, 15
    move $a0, $s6
    la   $a1, strFiltered
    li   $a2, 17
    syscall
    lw   $s2, ptr_output
    lw   $s5, N
    li   $s3, 0
w_loop:
    beq  $s3, $s5, w_mmse
    lwc1 $f12, 0($s2)
    mtc1 $zero, $f4
    cvt.s.w $f4, $f4
    c.lt.s $f12, $f4
    bc1f w_pos
    li   $v0, 15
    move $a0, $s6
    la   $a1, strMinus
    li   $a2, 1
    syscall
    neg.s $f12, $f12
w_pos:
    trunc.w.s $f0, $f12
    mfc1 $t0, $f0
    cvt.s.w $f1, $f0
    sub.s $f1, $f12, $f1
    l.s   $f2, ten
    mul.s $f1, $f1, $f2
    round.w.s $f1, $f1
    mfc1  $t1, $f1
    li    $t2, 10
    bne   $t1, $t2, w_ok
    addi  $t0, $t0, 1
    li    $t1, 0
w_ok:
    move  $a0, $t0
    jal   w_int
    li    $v0, 15
    move  $a0, $s6
    la    $a1, strDot
    li    $a2, 1
    syscall
    move  $a0, $t1
    jal   w_int
    li    $v0, 15
    move  $a0, $s6
    la    $a1, strSpace
    li    $a2, 1
    syscall
    addi  $s2, $s2, 4
    addi  $s3, $s3, 1
    j     w_loop

w_mmse:
    li    $v0, 15
    move  $a0, $s6
    la    $a1, strMMSE
    li    $a2, 7
    syscall
    mov.s $f12, $f30
    trunc.w.s $f0, $f12
    mfc1  $t0, $f0
    cvt.s.w $f1, $f0
    sub.s $f1, $f12, $f1
    l.s   $f2, ten
    mul.s $f1, $f1, $f2
    round.w.s $f1, $f1
    mfc1  $t1, $f1
    li    $t2, 10
    bne   $t1, $t2, wm_ok
    addi  $t0, $t0, 1
    li    $t1, 0
wm_ok:
    move  $a0, $t0
    jal   w_int
    li    $v0, 15
    move  $a0, $s6
    la    $a1, strDot
    li    $a2, 1
    syscall
    move  $a0, $t1
    jal   w_int

    li    $v0, 16
    move  $a0, $s6
    syscall
    j     exit

error_exit:
    li    $v0, 4
    la    $a0, errMsg
    syscall
exit:
    li    $v0, 10
    syscall

w_int:
    sub   $sp, $sp, 4
    sw    $ra, 0($sp)
    la    $t8, numBuffer
    move  $t9, $a0
    bnez  $t9, cvt
    li    $t7, 48
    sb    $t7, 0($t8)
    li    $a2, 1
    j     w_do
cvt:
    li    $t6, 0
    li    $t5, 10
psh: 
    beqz  $t9, pop
    div   $t9, $t5
    mfhi  $t7
    mflo  $t9
    addi  $t7, $t7, 48
    sub   $sp, $sp, 1
    sb    $t7, 0($sp)
    addi  $t6, $t6, 1
    j     psh
pop: 
    move  $a2, $t6
    li    $t5, 0
cpy: 
    beqz  $t6, w_do
    lb    $t7, 0($sp)
    add   $sp, $sp, 1
    add   $t4, $t8, $t5
    sb    $t7, 0($t4)
    addi  $t5, $t5, 1
    sub   $t6, $t6, 1
    j     cpy
w_do: 
    li    $v0, 15
    move  $a0, $s6
    la    $a1, numBuffer
    syscall
    lw    $ra, 0($sp)
    add   $sp, $sp, 4
    jr    $ra
