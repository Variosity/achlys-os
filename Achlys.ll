; ModuleID = 'achlys_kernel'
target triple = "x86_64-pc-linux-gnu"
declare i64 @fast_memcpy(i64, i64, i64)
declare i64 @fast_fill32(i64, i64, i64)
declare i64 @get_system_ticks()
@.fmt_int = private unnamed_addr constant [5 x i8] c"%ld\0A\00", align 8
@.fmt_str = private unnamed_addr constant [4 x i8] c"%s\0A\00", align 8
@.fmt_raw_s = private unnamed_addr constant [3 x i8] c"%s\00", align 8
@.fmt_raw_i = private unnamed_addr constant [4 x i8] c"%ld\00", align 8
@.mode_r = private unnamed_addr constant [2 x i8] c"r\00", align 8
@.mode_w = private unnamed_addr constant [2 x i8] c"w\00", align 8
@.str_lst = private unnamed_addr constant [7 x i8] c"<list>\00", align 8
@.str_map = private unnamed_addr constant [6 x i8] c"<map>\00", align 8
@__sys_argv = global i8** null, align 8
@__sys_argc = global i32 0, align 8
@.m_brk_l = private unnamed_addr constant [2 x i8] c"[\00", align 8
@.m_brk_r = private unnamed_addr constant [3 x i8] c"]\0A\00", align 8
@.m_comma = private unnamed_addr constant [3 x i8] c", \00", align 8
define i64 @_str_cat(i64 %a, i64 %b) {
  %sa = inttoptr i64 %a to i8*
  %sb = inttoptr i64 %b to i8*
  %la = call i64 @strlen(i8* %sa)
  %lb = call i64 @strlen(i8* %sb)
  %sz = add i64 %la, %lb
  %sz1 = add i64 %sz, 1
  %mem = call i64 @malloc(i64 %sz1)
  %ptr = inttoptr i64 %mem to i8*
  call i8* @strcpy(i8* %ptr, i8* %sa)
  call i8* @strcat(i8* %ptr, i8* %sb)
  ret i64 %mem
}
define i64 @to_string(i64 %val) {
  %is_ptr = icmp sgt i64 %val, 65536
  br i1 %is_ptr, label %is_str, label %is_int
is_str: ret i64 %val
is_int:
  %mem = call i64 @malloc(i64 32)
  %ptr = inttoptr i64 %mem to i8*
  %is_zero = icmp eq i64 %val, 0
  br i1 %is_zero, label %zero, label %calc
zero:
  store i8 48, i8* %ptr
  %zterm = getelementptr i8, i8* %ptr, i64 1
  store i8 0, i8* %zterm
  %zret = ptrtoint i8* %ptr to i64
  ret i64 %zret
calc:
  %is_neg = icmp slt i64 %val, 0
  %neg_val = sub i64 0, %val
  %abs_val = select i1 %is_neg, i64 %neg_val, i64 %val
  br label %loop
loop:
  %curr = phi i64 [ %abs_val, %calc ], [ %next_val, %loop ]
  %idx = phi i64 [ 30, %calc ], [ %next_idx, %loop ]
  %rem = srem i64 %curr, 10
  %char = add i64 %rem, 48
  %c8 = trunc i64 %char to i8
  %slot = getelementptr i8, i8* %ptr, i64 %idx
  store i8 %c8, i8* %slot
  %next_val = sdiv i64 %curr, 10
  %next_idx = sub i64 %idx, 1
  %stop = icmp eq i64 %next_val, 0
  br i1 %stop, label %done, label %loop
done:
  %start_idx = add i64 %next_idx, 1
  br i1 %is_neg, label %add_neg, label %copy
add_neg:
  %neg_slot = getelementptr i8, i8* %ptr, i64 %next_idx
  store i8 45, i8* %neg_slot
  br label %copy
copy:
  %final_start = phi i64 [ %start_idx, %done ], [ %next_idx, %add_neg ]
  %term_slot = getelementptr i8, i8* %ptr, i64 31
  store i8 0, i8* %term_slot
  %ret_ptr = getelementptr i8, i8* %ptr, i64 %final_start
  %ret_int = ptrtoint i8* %ret_ptr to i64
  ret i64 %ret_int
}
define i64 @_add(i64 %a, i64 %b) {
  %is_ptr_a = icmp sgt i64 %a, 65536
  %is_ptr_b = icmp sgt i64 %b, 65536
  %both_ptr = and i1 %is_ptr_a, %is_ptr_b
  %any_ptr = or i1 %is_ptr_a, %is_ptr_b
  br i1 %both_ptr, label %check_list, label %check_str
check_list:
  %ptr_a = inttoptr i64 %a to i8*
  %type_a = load i8, i8* %ptr_a
  %is_list = icmp eq i8 %type_a, 3
  br i1 %is_list, label %do_list, label %check_str
check_str:
  br i1 %any_ptr, label %do_str, label %int
do_str:
  %sa = call i64 @to_string(i64 %a)
  %sb = call i64 @to_string(i64 %b)
  %ret_str = call i64 @_str_cat(i64 %sa, i64 %sb)
  ret i64 %ret_str
do_list:
  %new_list = call i64 @_list_new()
  call void @_list_copy(i64 %new_list, i64 %a)
  call void @_list_copy(i64 %new_list, i64 %b)
  ret i64 %new_list
int:
  %ret_int = add i64 %a, %b
  ret i64 %ret_int
}
define void @_list_copy(i64 %dest, i64 %src) {
  %ptr = inttoptr i64 %src to i64*
  %cnt_ptr = getelementptr i64, i64* %ptr, i64 1
  %cnt = load i64, i64* %cnt_ptr
  %data_ptr = getelementptr i64, i64* %ptr, i64 2
  %base = load i64, i64* %data_ptr
  %base_ptr = inttoptr i64 %base to i64*
  br label %loop
loop:
  %i = phi i64 [ 0, %0 ], [ %next_i, %body ]
  %cond = icmp slt i64 %i, %cnt
  br i1 %cond, label %body, label %done
body:
  %slot = getelementptr i64, i64* %base_ptr, i64 %i
  %val = load i64, i64* %slot
  call i64 @_list_push(i64 %dest, i64 %val)
  %next_i = add i64 %i, 1
  br label %loop
done:
  ret void
}
define i64 @_append_poly(i64 %list, i64 %val) {
  %is_ptr = icmp sgt i64 %val, 65536
  br i1 %is_ptr, label %check_list, label %push_one
check_list:
  %ptr = inttoptr i64 %val to i8*
  %type = load i8, i8* %ptr
  %is_list = icmp eq i8 %type, 3
  br i1 %is_list, label %merge, label %push_one
merge:
  call void @_list_copy(i64 %list, i64 %val)
  ret i64 0
push_one:
  call i64 @_list_push(i64 %list, i64 %val)
  ret i64 0
}
define i64 @_eq(i64 %a, i64 %b) {
  %a_is_ptr = icmp sgt i64 %a, 65536
  %b_is_ptr = icmp sgt i64 %b, 65536
  %both_ptr = and i1 %a_is_ptr, %b_is_ptr
  br i1 %both_ptr, label %check_null, label %cmp_int
check_null:
  %a_null = icmp eq i64 %a, 0
  %b_null = icmp eq i64 %b, 0
  %any_null = or i1 %a_null, %b_null
  br i1 %any_null, label %cmp_int, label %cmp_str
cmp_str:
  %sa = inttoptr i64 %a to i8*
  %sb = inttoptr i64 %b to i8*
  %res = call i32 @strcmp(i8* %sa, i8* %sb)
  %iseq = icmp eq i32 %res, 0
  %ret_str = zext i1 %iseq to i64
  ret i64 %ret_str
cmp_int:
  %iseq_int = icmp eq i64 %a, %b
  %ret_int = zext i1 %iseq_int to i64
  ret i64 %ret_int
}
define i64 @_list_new() {
  %mem = call i64 @malloc(i64 24)
  %ptr = inttoptr i64 %mem to i64*
  store i64 3, i64* %ptr
  %cnt = getelementptr i64, i64* %ptr, i64 1
  store i64 0, i64* %cnt
  %data = getelementptr i64, i64* %ptr, i64 2
  store i64 0, i64* %data
  ret i64 %mem
}
define i64 @_list_set(i64 %l, i64 %idx, i64 %v) {
  %ptr = inttoptr i64 %l to i64*
  %data_ptr = getelementptr i64, i64* %ptr, i64 2
  %base = load i64, i64* %data_ptr
  %base_ptr = inttoptr i64 %base to i64*
  %slot = getelementptr i64, i64* %base_ptr, i64 %idx
  store i64 %v, i64* %slot
  ret i64 0
}
define i64 @_list_push(i64 %l, i64 %v) {
  %ptr = inttoptr i64 %l to i64*
  %cnt_ptr = getelementptr i64, i64* %ptr, i64 1
  %cnt = load i64, i64* %cnt_ptr
  %new_cnt = add i64 %cnt, 1
  store i64 %new_cnt, i64* %cnt_ptr
  %data_ptr = getelementptr i64, i64* %ptr, i64 2
  %old_mem_i = load i64, i64* %data_ptr
  %req_bytes = mul i64 %new_cnt, 8
  %old_ptr = inttoptr i64 %old_mem_i to i8*
  %new_ptr = call i8* @realloc(i8* %old_ptr, i64 %req_bytes)
  %new_mem = ptrtoint i8* %new_ptr to i64
  store i64 %new_mem, i64* %data_ptr
  %base_ptr = inttoptr i64 %new_mem to i64*
  %idx = getelementptr i64, i64* %base_ptr, i64 %cnt
  store i64 %v, i64* %idx
  ret i64 0
}
define i64 @_map_new() {
  %m = call i64 @_list_new()
  %ptr = inttoptr i64 %m to i64*
  store i64 4, i64* %ptr
  ret i64 %m
}
define i64 @_map_set(i64 %m, i64 %k, i64 %v) {
  call i64 @_list_push(i64 %m, i64 %k)
  call i64 @_list_push(i64 %m, i64 %v)
  ret i64 0
}
define i64 @_set(i64 %col, i64 %idx, i64 %v) {
  %ptr = inttoptr i64 %col to i64*
  %type = load i64, i64* %ptr
  %is_map = icmp eq i64 %type, 4
  br i1 %is_map, label %do_map, label %do_list
do_list:
  call i64 @_list_set(i64 %col, i64 %idx, i64 %v)
  ret i64 0
do_map:
  call i64 @_map_set(i64 %col, i64 %idx, i64 %v)
  ret i64 0
}
define i64 @_map_get(i64 %m, i64 %key) {
  %ptr = inttoptr i64 %m to i64*
  %cnt_ptr = getelementptr i64, i64* %ptr, i64 1
  %cnt = load i64, i64* %cnt_ptr
  %data_ptr = getelementptr i64, i64* %ptr, i64 2
  %base = load i64, i64* %data_ptr
  %base_ptr = inttoptr i64 %base to i64*
  %key_s = inttoptr i64 %key to i8*
  %start_i = sub i64 %cnt, 2
  br label %loop
loop:
  %i = phi i64 [ %start_i, %0 ], [ %next_i, %next ]
  %cond = icmp sge i64 %i, 0
  br i1 %cond, label %check_key, label %not_found
check_key:
  %k_slot = getelementptr i64, i64* %base_ptr, i64 %i
  %k_val = load i64, i64* %k_slot
  %k_str = inttoptr i64 %k_val to i8*
  %cmp = call i32 @strcmp(i8* %k_str, i8* %key_s)
  %match = icmp eq i32 %cmp, 0
  br i1 %match, label %found, label %next
next:
  %next_i = sub i64 %i, 2
  br label %loop
found:
  %v_idx = add i64 %i, 1
  %v_slot = getelementptr i64, i64* %base_ptr, i64 %v_idx
  %ret = load i64, i64* %v_slot
  ret i64 %ret
not_found:
  ret i64 0
}
define i64 @_get(i64 %col, i64 %idx) {
  %is_null = icmp eq i64 %col, 0
  br i1 %is_null, label %err, label %check
check:
  %ptr8 = inttoptr i64 %col to i8*
  %tag = load i8, i8* %ptr8
  %is_list = icmp eq i8 %tag, 3
  br i1 %is_list, label %do_list, label %check_map
check_map:
  %is_map = icmp eq i8 %tag, 4
  br i1 %is_map, label %do_map, label %do_str
do_str:
  %str_base = inttoptr i64 %col to i8*
  %char_ptr = getelementptr i8, i8* %str_base, i64 %idx
  %char = load i8, i8* %char_ptr
  %new_mem = call i64 @malloc(i64 2)
  %new_ptr = inttoptr i64 %new_mem to i8*
  store i8 %char, i8* %new_ptr
  %term = getelementptr i8, i8* %new_ptr, i64 1
  store i8 0, i8* %term
  %ret_str = ptrtoint i8* %new_ptr to i64
  ret i64 %ret_str
do_map:
  %map_val = call i64 @_map_get(i64 %col, i64 %idx)
  ret i64 %map_val
do_list:
  %ptr64 = inttoptr i64 %col to i64*
  %data_ptr = getelementptr i64, i64* %ptr64, i64 2
  %base = load i64, i64* %data_ptr
  %arr = inttoptr i64 %base to i64*
  %slot = getelementptr i64, i64* %arr, i64 %idx
  %val = load i64, i64* %slot
  ret i64 %val
err: ret i64 0
}
define i64 @codex(i64 %val) {
  %ptr = inttoptr i64 %val to i8*
  %c = load i8, i8* %ptr
  %ret = zext i8 %c to i64
  ret i64 %ret
}
define i64 @pars(i64 %str, i64 %start, i64 %len) {
  %src = inttoptr i64 %str to i8*
  %slen = call i64 @strlen(i8* %src)
  %is_oob = icmp sge i64 %start, %slen
  br i1 %is_oob, label %oob, label %ok
oob:
  %emp = call i64 @malloc(i64 1)
  %emp_p = inttoptr i64 %emp to i8*
  store i8 0, i8* %emp_p
  ret i64 %emp
ok:
  %rem = sub i64 %slen, %start
  %is_long = icmp sgt i64 %len, %rem
  %safe_len = select i1 %is_long, i64 %rem, i64 %len
  %src_off = getelementptr i8, i8* %src, i64 %start
  %alloc_sz = add i64 %safe_len, 1
  %dest = call i64 @malloc(i64 %alloc_sz)
  %dest_ptr = inttoptr i64 %dest to i8*
  call i8* @strncpy(i8* %dest_ptr, i8* %src_off, i64 %safe_len)
  %term = getelementptr i8, i8* %dest_ptr, i64 %safe_len
  store i8 0, i8* %term
  ret i64 %dest
}
define i64 @signum_ex(i64 %val) {
  %mem = call i64 @malloc(i64 2)
  %ptr = inttoptr i64 %mem to i8*
  %c = trunc i64 %val to i8
  store i8 %c, i8* %ptr
  %term = getelementptr i8, i8* %ptr, i64 1
  store i8 0, i8* %term
  ret i64 %mem
}
define i64 @mensura(i64 %val) {
  %is_null = icmp eq i64 %val, 0
  br i1 %is_null, label %ret_zero, label %read
ret_zero:
  ret i64 0
read:
  %ptr8 = inttoptr i64 %val to i8*
  %type = load i8, i8* %ptr8
  %is_list = icmp eq i8 %type, 3
  %is_map = icmp eq i8 %type, 4
  %is_col = or i1 %is_list, %is_map
  br i1 %is_col, label %get_cnt, label %get_str
get_cnt:
  %ptr64 = inttoptr i64 %val to i64*
  %cnt_ptr = getelementptr i64, i64* %ptr64, i64 1
  %cnt = load i64, i64* %cnt_ptr
  ret i64 %cnt
get_str:
  %str_ptr = inttoptr i64 %val to i8*
  %len = call i64 @strlen(i8* %str_ptr)
  ret i64 %len
}
define i64 @iunctura(i64 %list_ptr, i64 %delim) {
  %is_null = icmp eq i64 %list_ptr, 0
  br i1 %is_null, label %ret_empty, label %check
check:
  %ptr64 = inttoptr i64 %list_ptr to i64*
  %cnt_ptr = getelementptr i64, i64* %ptr64, i64 1
  %cnt = load i64, i64* %cnt_ptr
  %is_empty = icmp eq i64 %cnt, 0
  br i1 %is_empty, label %ret_empty, label %calc
ret_empty:
  %emp = call i64 @malloc(i64 1)
  %emp_p = inttoptr i64 %emp to i8*
  store i8 0, i8* %emp_p
  ret i64 %emp
calc:
  %data_ptr = getelementptr i64, i64* %ptr64, i64 2
  %base = load i64, i64* %data_ptr
  %base_ptr = inttoptr i64 %base to i64*
  %res_0 = call i64 @malloc(i64 1)
  %res_0_p = inttoptr i64 %res_0 to i8*
  store i8 0, i8* %res_0_p
  br label %loop
loop:
  %i = phi i64 [ 0, %calc ], [ %next_i, %merge ]
  %curr_str = phi i64 [ %res_0, %calc ], [ %next_str, %merge ]
  %cond = icmp slt i64 %i, %cnt
  br i1 %cond, label %body, label %done
body:
  %slot = getelementptr i64, i64* %base_ptr, i64 %i
  %item = load i64, i64* %slot
  %item_s = call i64 @to_string(i64 %item)
  %added = call i64 @_str_cat(i64 %curr_str, i64 %item_s)
  %last_idx = sub i64 %cnt, 1
  %is_last = icmp eq i64 %i, %last_idx
  br i1 %is_last, label %skip_delim, label %add_delim
add_delim:
  %with_delim = call i64 @_str_cat(i64 %added, i64 %delim)
  br label %merge
skip_delim:
  br label %merge
merge:
  %next_str = phi i64 [ %with_delim, %add_delim ], [ %added, %skip_delim ]
  %next_i = add i64 %i, 1
  br label %loop
done:
  ret i64 %curr_str
}
define i64 @syscall6(i64 %sys_no, i64 %a1, i64 %a2, i64 %a3, i64 %a4, i64 %a5, i64 %a6) {
  %res = call i64 asm sideeffect "syscall", "={rax},{rax},{rdi},{rsi},{rdx},{r10},{r8},{r9},~{rcx},~{r11},~{memory}"(i64 %sys_no, i64 %a1, i64 %a2, i64 %a3, i64 %a4, i64 %a5, i64 %a6)
  ret i64 %res
}
define i64 @strlen(i8* %str) {
entry: br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %nxt, %loop ]
  %ptr = getelementptr i8, i8* %str, i64 %i
  %c = load i8, i8* %ptr
  %is_null = icmp eq i8 %c, 0
  %nxt = add i64 %i, 1
  br i1 %is_null, label %done, label %loop
done: ret i64 %i
}
define i32 @strcmp(i8* %s1, i8* %s2) {
entry: br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %nxt, %loop ]
  %p1 = getelementptr i8, i8* %s1, i64 %i
  %p2 = getelementptr i8, i8* %s2, i64 %i
  %c1 = load i8, i8* %p1
  %c2 = load i8, i8* %p2
  %not_eq = icmp ne i8 %c1, %c2
  %is_null = icmp eq i8 %c1, 0
  %stop = or i1 %not_eq, %is_null
  %nxt = add i64 %i, 1
  br i1 %stop, label %done, label %loop
done:
  %z1 = zext i8 %c1 to i32
  %z2 = zext i8 %c2 to i32
  %diff = sub i32 %z1, %z2
  ret i32 %diff
}
define i8* @strcpy(i8* %dest, i8* %src) {
entry: br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %nxt, %loop ]
  %ps = getelementptr i8, i8* %src, i64 %i
  %pd = getelementptr i8, i8* %dest, i64 %i
  %c = load i8, i8* %ps
  store i8 %c, i8* %pd
  %is_null = icmp eq i8 %c, 0
  %nxt = add i64 %i, 1
  br i1 %is_null, label %done, label %loop
done: ret i8* %dest
}
define i8* @strncpy(i8* %dest, i8* %src, i64 %n) {
entry: br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %nxt, %body ]
  %cmp = icmp slt i64 %i, %n
  br i1 %cmp, label %body, label %done
body:
  %ps = getelementptr i8, i8* %src, i64 %i
  %pd = getelementptr i8, i8* %dest, i64 %i
  %c = load i8, i8* %ps
  store i8 %c, i8* %pd
  %nxt = add i64 %i, 1
  br label %loop
done: ret i8* %dest
}
define i8* @strcat(i8* %dest, i8* %src) {
  %len = call i64 @strlen(i8* %dest)
  %d_end = getelementptr i8, i8* %dest, i64 %len
  call i8* @strcpy(i8* %d_end, i8* %src)
  ret i8* %dest
}
@kernel_heap = global i64 0
@FB_ADDR = global i64 0
@BACK_BUFFER = global i64 0
@FB_PITCH = global i64 0
@FB_WIDTH = global i64 0
@FB_HEIGHT = global i64 0
@.sc.1 = global i64 0
@.sc.2 = global i64 0
@.sc.3 = global i64 0
@.sc.4 = global i64 0
@.sc.5 = global i64 0
@.sc.6 = global i64 0
@.sc.7 = global i64 0
@.sc.8 = global i64 0
@.str.9 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.10 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.11 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@kbd_map = global i64 0
@shift_map = global i64 0
@.sc.12 = global i64 0
@.str.13 = private unnamed_addr constant [1 x i8] c"\00", align 8
@FONT = global i64 0
@.sc.14 = global i64 0
@cam_x = global i64 0
@cam_y = global i64 0
@cam_z = global i64 0
@.sc.15 = global i64 0
@.sc.16 = global i64 0
@.sc.17 = global i64 0
@mouse_x = global i64 0
@mouse_y = global i64 0
@mouse_l_down = global i64 0
@mouse_r_down = global i64 0
@.sc.18 = global i64 0
@.sc.19 = global i64 0
@.sc.20 = global i64 0
@.sc.21 = global i64 0
@.sc.22 = global i64 0
@.sc.23 = global i64 0
@.sc.24 = global i64 0
@.sc.25 = global i64 0
@E1000_BAR = global i64 0
@.str.26 = private unnamed_addr constant [2 x i8] c":\00", align 8
@.str.27 = private unnamed_addr constant [2 x i8] c":\00", align 8
@.str.28 = private unnamed_addr constant [2 x i8] c":\00", align 8
@.str.29 = private unnamed_addr constant [2 x i8] c":\00", align 8
@.str.30 = private unnamed_addr constant [2 x i8] c":\00", align 8
@E1000_TX_DESC = global i64 0
@E1000_TX_TAIL = global i64 0
@E1000_RX_DESC = global i64 0
@E1000_RX_CUR = global i64 0
@E1000_RX_LEN = global i64 0
@TOK_EOF = global i64 0
@TOK_INT = global i64 0
@TOK_FLOAT = global i64 0
@TOK_STRING = global i64 0
@TOK_IDENT = global i64 0
@TOK_LET = global i64 0
@TOK_PRINT = global i64 0
@TOK_IF = global i64 0
@TOK_ELSE = global i64 0
@TOK_WHILE = global i64 0
@TOK_OPUS = global i64 0
@TOK_REDDO = global i64 0
@TOK_BREAK = global i64 0
@TOK_CONTINUE = global i64 0
@TOK_IMPORT = global i64 0
@TOK_LPAREN = global i64 0
@TOK_RPAREN = global i64 0
@TOK_LBRACE = global i64 0
@TOK_RBRACE = global i64 0
@TOK_LBRACKET = global i64 0
@TOK_RBRACKET = global i64 0
@TOK_COLON = global i64 0
@TOK_ARROW = global i64 0
@TOK_CARET = global i64 0
@TOK_DOT = global i64 0
@TOK_APPEND = global i64 0
@TOK_EXTRACT = global i64 0
@TOK_AND = global i64 0
@TOK_OR = global i64 0
@TOK_CONST = global i64 0
@TOK_SHARED = global i64 0
@TOK_OP = global i64 0
@TOK_COMMA = global i64 0
@EXPR_INT = global i64 0
@EXPR_FLOAT = global i64 0
@EXPR_STRING = global i64 0
@EXPR_VAR = global i64 0
@EXPR_LIST = global i64 0
@EXPR_MAP = global i64 0
@EXPR_BINARY = global i64 0
@EXPR_INDEX = global i64 0
@EXPR_GET = global i64 0
@EXPR_CALL = global i64 0
@EXPR_INPUT = global i64 0
@EXPR_READ = global i64 0
@EXPR_MEASURE = global i64 0
@STMT_LET = global i64 0
@STMT_ASSIGN = global i64 0
@STMT_SET = global i64 0
@STMT_SET_INDEX = global i64 0
@STMT_APPEND = global i64 0
@STMT_EXTRACT = global i64 0
@STMT_PRINT = global i64 0
@STMT_IF = global i64 0
@STMT_WHILE = global i64 0
@STMT_FUNC = global i64 0
@STMT_RETURN = global i64 0
@STMT_IMPORT = global i64 0
@STMT_BREAK = global i64 0
@STMT_CONTINUE = global i64 0
@STMT_EXPR = global i64 0
@STMT_CONST = global i64 0
@STMT_SHARED = global i64 0
@VAL_INT = global i64 0
@VAL_FLOAT = global i64 0
@VAL_STRING = global i64 0
@VAL_LIST = global i64 0
@VAL_MAP = global i64 0
@VAL_FUNC = global i64 0
@VAL_VOID = global i64 0
@global_tokens = global i64 0
@p_pos = global i64 0
@has_error = global i64 0
@use_huge_lists = global i64 0
@str_table = global i64 0
@stack_map = global i64 0
@stack_offset = global i64 0
@lbl_counter = global i64 0
@asm_main = global i64 0
@asm_funcs = global i64 0
@in_func = global i64 0
@local_vars = global i64 0
@stack_depth = global i64 0
@.str.31 = private unnamed_addr constant [2 x i8] c"_\00", align 8
@.str.32 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.33 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.34 = private unnamed_addr constant [4 x i8] c"txt\00", align 8
@.str.35 = private unnamed_addr constant [4 x i8] c"lbl\00", align 8
@.str.36 = private unnamed_addr constant [5 x i8] c"str_\00", align 8
@.str.37 = private unnamed_addr constant [4 x i8] c"txt\00", align 8
@.str.38 = private unnamed_addr constant [4 x i8] c"lbl\00", align 8
@.str.39 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.40 = private unnamed_addr constant [3 x i8] c", \00", align 8
@.str.41 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.42 = private unnamed_addr constant [11 x i8] c"engine.nox\00", align 8
@.str.43 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.44 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.45 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.46 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.47 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.48 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.49 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.50 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.sc.51 = global i64 0
@.str.52 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.str.53 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.54 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.55 = private unnamed_addr constant [2 x i8] c"\22\00", align 8
@.str.56 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.57 = private unnamed_addr constant [2 x i8] c"\22\00", align 8
@.str.58 = private unnamed_addr constant [2 x i8] c"\5C\00", align 8
@.str.59 = private unnamed_addr constant [2 x i8] c"n\00", align 8
@.str.60 = private unnamed_addr constant [2 x i8] c"t\00", align 8
@.str.61 = private unnamed_addr constant [2 x i8] c"\22\00", align 8
@.str.62 = private unnamed_addr constant [2 x i8] c"\22\00", align 8
@.str.63 = private unnamed_addr constant [2 x i8] c"\5C\00", align 8
@.str.64 = private unnamed_addr constant [2 x i8] c"\5C\00", align 8
@.str.65 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.66 = private unnamed_addr constant [2 x i8] c"x\00", align 8
@.str.67 = private unnamed_addr constant [2 x i8] c"X\00", align 8
@.str.68 = private unnamed_addr constant [2 x i8] c".\00", align 8
@.str.69 = private unnamed_addr constant [4 x i8] c"vas\00", align 8
@.str.70 = private unnamed_addr constant [5 x i8] c"idea\00", align 8
@.str.71 = private unnamed_addr constant [6 x i8] c"umbra\00", align 8
@.str.72 = private unnamed_addr constant [7 x i8] c"scribo\00", align 8
@.str.73 = private unnamed_addr constant [8 x i8] c"monstro\00", align 8
@.str.74 = private unnamed_addr constant [10 x i8] c"insusurro\00", align 8
@.str.75 = private unnamed_addr constant [3 x i8] c"si\00", align 8
@.str.76 = private unnamed_addr constant [7 x i8] c"aliter\00", align 8
@.str.77 = private unnamed_addr constant [4 x i8] c"dum\00", align 8
@.str.78 = private unnamed_addr constant [5 x i8] c"opus\00", align 8
@.str.79 = private unnamed_addr constant [6 x i8] c"reddo\00", align 8
@.str.80 = private unnamed_addr constant [10 x i8] c"abrumpere\00", align 8
@.str.81 = private unnamed_addr constant [8 x i8] c"pergere\00", align 8
@.str.82 = private unnamed_addr constant [10 x i8] c"importare\00", align 8
@.str.83 = private unnamed_addr constant [9 x i8] c"constans\00", align 8
@.str.84 = private unnamed_addr constant [9 x i8] c"communis\00", align 8
@.str.85 = private unnamed_addr constant [4 x i8] c"xor\00", align 8
@.str.86 = private unnamed_addr constant [2 x i8] c"^\00", align 8
@.str.87 = private unnamed_addr constant [3 x i8] c"et\00", align 8
@.str.88 = private unnamed_addr constant [4 x i8] c"vel\00", align 8
@.str.89 = private unnamed_addr constant [6 x i8] c"verum\00", align 8
@.str.90 = private unnamed_addr constant [2 x i8] c"1\00", align 8
@.str.91 = private unnamed_addr constant [7 x i8] c"falsum\00", align 8
@.str.92 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.93 = private unnamed_addr constant [2 x i8] c"(\00", align 8
@.str.94 = private unnamed_addr constant [2 x i8] c")\00", align 8
@.str.95 = private unnamed_addr constant [2 x i8] c"{\00", align 8
@.str.96 = private unnamed_addr constant [2 x i8] c"}\00", align 8
@.str.97 = private unnamed_addr constant [2 x i8] c"[\00", align 8
@.str.98 = private unnamed_addr constant [2 x i8] c"]\00", align 8
@.str.99 = private unnamed_addr constant [2 x i8] c":\00", align 8
@.str.100 = private unnamed_addr constant [2 x i8] c"^\00", align 8
@.str.101 = private unnamed_addr constant [2 x i8] c".\00", align 8
@.str.102 = private unnamed_addr constant [2 x i8] c",\00", align 8
@.str.103 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@.str.104 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.105 = private unnamed_addr constant [3 x i8] c"->\00", align 8
@.str.106 = private unnamed_addr constant [2 x i8] c"=\00", align 8
@.str.107 = private unnamed_addr constant [2 x i8] c"=\00", align 8
@.str.108 = private unnamed_addr constant [3 x i8] c"==\00", align 8
@.str.109 = private unnamed_addr constant [2 x i8] c"!\00", align 8
@.str.110 = private unnamed_addr constant [2 x i8] c"=\00", align 8
@.str.111 = private unnamed_addr constant [3 x i8] c"!=\00", align 8
@.str.112 = private unnamed_addr constant [2 x i8] c"<\00", align 8
@.str.113 = private unnamed_addr constant [2 x i8] c"<\00", align 8
@.str.114 = private unnamed_addr constant [2 x i8] c"<\00", align 8
@.str.115 = private unnamed_addr constant [4 x i8] c"<<<\00", align 8
@.str.116 = private unnamed_addr constant [3 x i8] c"<<\00", align 8
@.str.117 = private unnamed_addr constant [2 x i8] c"=\00", align 8
@.str.118 = private unnamed_addr constant [3 x i8] c"<=\00", align 8
@.str.119 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.120 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.121 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.122 = private unnamed_addr constant [4 x i8] c">>>\00", align 8
@.str.123 = private unnamed_addr constant [3 x i8] c">>\00", align 8
@.str.124 = private unnamed_addr constant [2 x i8] c"=\00", align 8
@.str.125 = private unnamed_addr constant [3 x i8] c">=\00", align 8
@.str.126 = private unnamed_addr constant [4 x i8] c"EOF\00", align 8
@.str.127 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.128 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.129 = private unnamed_addr constant [4 x i8] c"EOF\00", align 8
@.str.130 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.131 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.132 = private unnamed_addr constant [21 x i8] c"Expected token type \00", align 8
@.str.133 = private unnamed_addr constant [10 x i8] c" but got \00", align 8
@.str.134 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.135 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.136 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.137 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.138 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.139 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.140 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.141 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.142 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.143 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.144 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.145 = private unnamed_addr constant [5 x i8] c"args\00", align 8
@.str.146 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.147 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.148 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.149 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.150 = private unnamed_addr constant [6 x i8] c"items\00", align 8
@.str.151 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.152 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.153 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.154 = private unnamed_addr constant [5 x i8] c"keys\00", align 8
@.str.155 = private unnamed_addr constant [5 x i8] c"vals\00", align 8
@.sc.156 = global i64 0
@.str.157 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.158 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.159 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@.str.160 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.161 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.162 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@.str.163 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.164 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.165 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.166 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.167 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.sc.168 = global i64 0
@.str.169 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.170 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.171 = private unnamed_addr constant [2 x i8] c"!\00", align 8
@.str.172 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.173 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.174 = private unnamed_addr constant [3 x i8] c"==\00", align 8
@.str.175 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.176 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.str.177 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.178 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.179 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.180 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.181 = private unnamed_addr constant [19 x i8] c"Unexpected token: \00", align 8
@.str.182 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.183 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.184 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.185 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.186 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.187 = private unnamed_addr constant [4 x i8] c"obj\00", align 8
@.str.188 = private unnamed_addr constant [4 x i8] c"idx\00", align 8
@.str.189 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.190 = private unnamed_addr constant [4 x i8] c"obj\00", align 8
@.str.191 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.192 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.193 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.194 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.195 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.str.196 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.197 = private unnamed_addr constant [2 x i8] c"%\00", align 8
@.str.198 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.199 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.200 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.201 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.202 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.str.203 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.204 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.205 = private unnamed_addr constant [2 x i8] c"+\00", align 8
@.str.206 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@.str.207 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.208 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.209 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.210 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.211 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.str.212 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.213 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.214 = private unnamed_addr constant [2 x i8] c"^\00", align 8
@.str.215 = private unnamed_addr constant [2 x i8] c"&\00", align 8
@.str.216 = private unnamed_addr constant [2 x i8] c"|\00", align 8
@.str.217 = private unnamed_addr constant [4 x i8] c"<<<\00", align 8
@.str.218 = private unnamed_addr constant [4 x i8] c">>>\00", align 8
@.str.219 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.220 = private unnamed_addr constant [4 x i8] c"xor\00", align 8
@.str.221 = private unnamed_addr constant [2 x i8] c"^\00", align 8
@.str.222 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.223 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.224 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.225 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.str.226 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.227 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.228 = private unnamed_addr constant [3 x i8] c"==\00", align 8
@.str.229 = private unnamed_addr constant [3 x i8] c"!=\00", align 8
@.str.230 = private unnamed_addr constant [2 x i8] c"<\00", align 8
@.str.231 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.232 = private unnamed_addr constant [3 x i8] c"<=\00", align 8
@.str.233 = private unnamed_addr constant [3 x i8] c">=\00", align 8
@.str.234 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.235 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.236 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.237 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.238 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.sc.239 = global i64 0
@.str.240 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.241 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.242 = private unnamed_addr constant [3 x i8] c"et\00", align 8
@.str.243 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.244 = private unnamed_addr constant [4 x i8] c"vel\00", align 8
@.str.245 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.246 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.247 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.248 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.str.249 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.250 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.251 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.252 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.253 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.254 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.255 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.256 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.257 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.258 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.259 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.260 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.261 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.262 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.263 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.264 = private unnamed_addr constant [5 x i8] c"cond\00", align 8
@.str.265 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.266 = private unnamed_addr constant [5 x i8] c"else\00", align 8
@.str.267 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.268 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.269 = private unnamed_addr constant [5 x i8] c"cond\00", align 8
@.str.270 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.271 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.272 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.273 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.274 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.275 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.276 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.277 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.278 = private unnamed_addr constant [7 x i8] c"params\00", align 8
@.str.279 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.280 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.281 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.282 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.283 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.284 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.285 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.286 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.287 = private unnamed_addr constant [15 x i8] c"Unexpected EOF\00", align 8
@.str.288 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.289 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.290 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.291 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.292 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.293 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.294 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.295 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.296 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.297 = private unnamed_addr constant [5 x i8] c"text\00", align 8
@.str.298 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.299 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.300 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.301 = private unnamed_addr constant [4 x i8] c"obj\00", align 8
@.str.302 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.303 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.304 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.305 = private unnamed_addr constant [4 x i8] c"idx\00", align 8
@.str.306 = private unnamed_addr constant [4 x i8] c"idx\00", align 8
@.str.307 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.308 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.309 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.310 = private unnamed_addr constant [5 x i8] c"expr\00", align 8
@.str.311 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.312 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@runtime_env = global i64 0
@eval_terminal = global i64 0
@.str.313 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.314 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.315 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.316 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.317 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.318 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.319 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.320 = private unnamed_addr constant [3 x i8] c"op\00", align 8
@.str.321 = private unnamed_addr constant [5 x i8] c"left\00", align 8
@.str.322 = private unnamed_addr constant [6 x i8] c"right\00", align 8
@.str.323 = private unnamed_addr constant [2 x i8] c"+\00", align 8
@.str.324 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@.str.325 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.str.326 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.327 = private unnamed_addr constant [2 x i8] c"<\00", align 8
@.str.328 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.329 = private unnamed_addr constant [3 x i8] c"==\00", align 8
@.sc.330 = global i64 0
@.str.331 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.332 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.333 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.334 = private unnamed_addr constant [5 x i8] c"name\00", align 8
@.str.335 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.336 = private unnamed_addr constant [4 x i8] c"val\00", align 8
@.str.337 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.338 = private unnamed_addr constant [5 x i8] c"IPC:\00", align 8
@.str.339 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.340 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.341 = private unnamed_addr constant [5 x i8] c"cond\00", align 8
@.str.342 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.343 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.344 = private unnamed_addr constant [5 x i8] c"else\00", align 8
@.str.345 = private unnamed_addr constant [5 x i8] c"else\00", align 8
@.str.346 = private unnamed_addr constant [5 x i8] c"else\00", align 8
@.str.347 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.348 = private unnamed_addr constant [5 x i8] c"cond\00", align 8
@.str.349 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.350 = private unnamed_addr constant [5 x i8] c"body\00", align 8
@.str.351 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.352 = private unnamed_addr constant [5 x i8] c"type\00", align 8
@.str.353 = private unnamed_addr constant [42 x i8] c"IPC:>> ACHLYS NATIVE ENGINE INITIATED...\0A\00", align 8
@.str.354 = private unnamed_addr constant [28 x i8] c"IPC:>> EXECUTION COMPLETE.\0A\00", align 8
@actor_x = global i64 0
@actor_y = global i64 0
@actor_w = global i64 0
@actor_h = global i64 0
@actor_text = global i64 0
@actor_cmd = global i64 0
@actor_mailbox = global i64 0
@actor_budget = global i64 0
@actor_app = global i64 0
@actor_file_buf = global i64 0
@actor_target = global i64 0
@wire_from = global i64 0
@wire_to = global i64 0
@grabbed_node = global i64 0
@focused_node = global i64 0
@routing_node = global i64 0
@resizing_node = global i64 0
@omni_text = global i64 0
@paradigm = global i64 0
@mouse_has_wheel = global i64 0
@tcp_global_seq = global i64 0
@rand_seed = global i64 0
@MAX_PARTS = global i64 0
@part_x = global i64 0
@part_y = global i64 0
@part_vx = global i64 0
@part_vy = global i64 0
@part_life = global i64 0
@.sc.355 = global i64 0
@.str.356 = private unnamed_addr constant [20 x i8] c"KERNEL PANIC - INT \00", align 8
@.sc.357 = global i64 0
@.str.358 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.sc.359 = global i64 0
@.str.360 = private unnamed_addr constant [2 x i8] c"^\00", align 8
@.str.361 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.sc.362 = global i64 0
@.sc.363 = global i64 0
@.str.364 = private unnamed_addr constant [8 x i8] c"prints \00", align 8
@.str.365 = private unnamed_addr constant [5 x i8] c"IPC:\00", align 8
@.str.366 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.sc.367 = global i64 0
@.str.368 = private unnamed_addr constant [7 x i8] c"print \00", align 8
@.sc.369 = global i64 0
@.str.370 = private unnamed_addr constant [5 x i8] c"IPC:\00", align 8
@.str.371 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.sc.372 = global i64 0
@.str.373 = private unnamed_addr constant [5 x i8] c"let \00", align 8
@.sc.374 = global i64 0
@.sc.375 = global i64 0
@.str.376 = private unnamed_addr constant [5 x i8] c"add \00", align 8
@.sc.377 = global i64 0
@.sc.378 = global i64 0
@.str.379 = private unnamed_addr constant [5 x i8] c"sub \00", align 8
@.sc.380 = global i64 0
@.sc.381 = global i64 0
@.str.382 = private unnamed_addr constant [6 x i8] c"goto \00", align 8
@.sc.383 = global i64 0
@.str.384 = private unnamed_addr constant [5 x i8] c"jlt \00", align 8
@.str.385 = private unnamed_addr constant [2 x i8] c" \00", align 8
@.sc.386 = global i64 0
@.sc.387 = global i64 0
@.str.388 = private unnamed_addr constant [27 x i8] c"IPC:>> VM HALTED. CYCLES: \00", align 8
@.str.389 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@vfs_name = global i64 0
@vfs_start = global i64 0
@vfs_size = global i64 0
@.str.390 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.391 = private unnamed_addr constant [8 x i8] c"ash.nox\00", align 8
@.str.392 = private unnamed_addr constant [13 x i8] c"scriptor.nox\00", align 8
@.str.393 = private unnamed_addr constant [11 x i8] c"umbrae.nox\00", align 8
@.str.394 = private unnamed_addr constant [5 x i8] c"mod_\00", align 8
@.str.395 = private unnamed_addr constant [5 x i8] c".nox\00", align 8
@.str.396 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.397 = private unnamed_addr constant [24 x i8] c"ERROR: File not found: \00", align 8
@.sc.398 = global i64 0
@.sc.399 = global i64 0
@.str.400 = private unnamed_addr constant [19 x i8] c"ORDER//CONSTRUCT> \00", align 8
@.str.401 = private unnamed_addr constant [14 x i8] c"CHAOS//VOID> \00", align 8
@.str.402 = private unnamed_addr constant [2 x i8] c"_\00", align 8
@.sc.403 = global i64 0
@.sc.404 = global i64 0
@.sc.405 = global i64 0
@.sc.406 = global i64 0
@.sc.407 = global i64 0
@.sc.408 = global i64 0
@.sc.409 = global i64 0
@.str.410 = private unnamed_addr constant [2 x i8] c"`\00", align 8
@.str.411 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.412 = private unnamed_addr constant [2 x i8] c"`\00", align 8
@.str.413 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.414 = private unnamed_addr constant [10 x i8] c"BACKSPACE\00", align 8
@.str.415 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.416 = private unnamed_addr constant [6 x i8] c"ENTER\00", align 8
@.str.417 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.418 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.419 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.420 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.421 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.422 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.423 = private unnamed_addr constant [5 x i8] c"ping\00", align 8
@.str.424 = private unnamed_addr constant [6 x i8] c"pong\0A\00", align 8
@.str.425 = private unnamed_addr constant [4 x i8] c"los\00", align 8
@.str.426 = private unnamed_addr constant [3 x i8] c" (\00", align 8
@.str.427 = private unnamed_addr constant [5 x i8] c" B)\0A\00", align 8
@.str.428 = private unnamed_addr constant [6 x i8] c"read \00", align 8
@.str.429 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.430 = private unnamed_addr constant [6 x i8] c"edit \00", align 8
@.str.431 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.432 = private unnamed_addr constant [30 x i8] c">> SCRIPTOR ONLINE. EDITING: \00", align 8
@.str.433 = private unnamed_addr constant [47 x i8] c"\0A[COMMANDS: :w (save), :p (print), :q (exit)]\0A\00", align 8
@.str.434 = private unnamed_addr constant [5 x i8] c"run \00", align 8
@.str.435 = private unnamed_addr constant [8 x i8] c"ash.nox\00", align 8
@.str.436 = private unnamed_addr constant [26 x i8] c">> ASH SHELL INJECTED...\0A\00", align 8
@.str.437 = private unnamed_addr constant [13 x i8] c"scriptor.nox\00", align 8
@.str.438 = private unnamed_addr constant [21 x i8] c">> SCRIPTOR ONLINE.\0A\00", align 8
@.str.439 = private unnamed_addr constant [5 x i8] c".nox\00", align 8
@.str.440 = private unnamed_addr constant [33 x i8] c">> EXECUTING MICRO-VM BINARY...\0A\00", align 8
@.str.441 = private unnamed_addr constant [35 x i8] c"Execution denied or file missing: \00", align 8
@.str.442 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.443 = private unnamed_addr constant [6 x i8] c"lspci\00", align 8
@.str.444 = private unnamed_addr constant [28 x i8] c">> SCANNING MOTHERBOARD...\0A\00", align 8
@.str.445 = private unnamed_addr constant [5 x i8] c"BUS \00", align 8
@.str.446 = private unnamed_addr constant [7 x i8] c" SLOT \00", align 8
@.str.447 = private unnamed_addr constant [13 x i8] c" -> VENDOR: \00", align 8
@.str.448 = private unnamed_addr constant [12 x i8] c" | DEVICE: \00", align 8
@.str.449 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.sc.450 = global i64 0
@.str.451 = private unnamed_addr constant [37 x i8] c"[!] E1000 NIC MOUNTED AT MMIO BASE: \00", align 8
@.str.452 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.453 = private unnamed_addr constant [26 x i8] c"[!] MAC ADDRESS SECURED: \00", align 8
@.str.454 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.455 = private unnamed_addr constant [43 x i8] c"[!] TX/RX RING BUFFERS: ONLINE AND ARMED.\0A\00", align 8
@.str.456 = private unnamed_addr constant [8 x i8] c"tx_test\00", align 8
@.str.457 = private unnamed_addr constant [37 x i8] c">> ERR: NIC NOT MOUNTED. RUN lspci.\0A\00", align 8
@.str.458 = private unnamed_addr constant [44 x i8] c">> [DMA] INJECTING L2 ARP REQUEST FRAME...\0A\00", align 8
@.sc.459 = global i64 0
@.str.460 = private unnamed_addr constant [46 x i8] c">> [HW] E1000 CONFIRMS TRANSMISSION SUCCESS!\0A\00", align 8
@.str.461 = private unnamed_addr constant [39 x i8] c">> [HW] ERR: NIC TIMEOUT. DMA FAILED.\0A\00", align 8
@.str.462 = private unnamed_addr constant [8 x i8] c"rx_test\00", align 8
@.str.463 = private unnamed_addr constant [37 x i8] c">> ERR: NIC NOT MOUNTED. RUN lspci.\0A\00", align 8
@.str.464 = private unnamed_addr constant [33 x i8] c">> [RX] PACKET SECURED! LENGTH: \00", align 8
@.str.465 = private unnamed_addr constant [8 x i8] c" BYTES\0A\00", align 8
@.str.466 = private unnamed_addr constant [33 x i8] c">> [RX] PAYLOAD DUMP (DECIMAL):\0A\00", align 8
@.str.467 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.sc.468 = global i64 0
@.str.469 = private unnamed_addr constant [2 x i8] c" \00", align 8
@.str.470 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.471 = private unnamed_addr constant [40 x i8] c">> [RX] SILENCE. NO PACKETS IN BUFFER.\0A\00", align 8
@.str.472 = private unnamed_addr constant [9 x i8] c"dns_test\00", align 8
@.str.473 = private unnamed_addr constant [37 x i8] c">> ERR: NIC NOT MOUNTED. RUN lspci.\0A\00", align 8
@.str.474 = private unnamed_addr constant [53 x i8] c">> [DNS] FORGING IPv4/UDP QUERY FOR 'google.com'...\0A\00", align 8
@.sc.475 = global i64 0
@.str.476 = private unnamed_addr constant [56 x i8] c">> [HW] TRANSMISSION SUCCESS! WAITING FOR DNS REPLY...\0A\00", align 8
@.sc.477 = global i64 0
@.str.478 = private unnamed_addr constant [41 x i8] c">> [DNS] UDP REPLY SECURED! DECODING...\0A\00", align 8
@.str.479 = private unnamed_addr constant [23 x i8] c">> [DNS] google.com = \00", align 8
@.str.480 = private unnamed_addr constant [2 x i8] c".\00", align 8
@.str.481 = private unnamed_addr constant [2 x i8] c".\00", align 8
@.str.482 = private unnamed_addr constant [2 x i8] c".\00", align 8
@.str.483 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.484 = private unnamed_addr constant [45 x i8] c">> [ERR] RX TIMEOUT. NO DNS REPLY RECEIVED.\0A\00", align 8
@.str.485 = private unnamed_addr constant [39 x i8] c">> [HW] ERR: NIC TIMEOUT. DMA FAILED.\0A\00", align 8
@.str.486 = private unnamed_addr constant [11 x i8] c"tcp_strike\00", align 8
@.str.487 = private unnamed_addr constant [37 x i8] c">> ERR: NIC NOT MOUNTED. RUN lspci.\0A\00", align 8
@.str.488 = private unnamed_addr constant [56 x i8] c">> [DIAGNOSTIC] FLUSHING RX RING AND FIRING TCP SYN...\0A\00", align 8
@.sc.489 = global i64 0
@.sc.490 = global i64 0
@.str.491 = private unnamed_addr constant [15 x i8] c">> IPV4 DUMP: \00", align 8
@.str.492 = private unnamed_addr constant [2 x i8] c" \00", align 8
@.str.493 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.494 = private unnamed_addr constant [51 x i8] c">> [ERR] ABSOLUTE SILENCE. HYPERVISOR DROPPED IT.\0A\00", align 8
@.str.495 = private unnamed_addr constant [10 x i8] c"http_test\00", align 8
@.str.496 = private unnamed_addr constant [37 x i8] c">> ERR: NIC NOT MOUNTED. RUN lspci.\0A\00", align 8
@.str.497 = private unnamed_addr constant [38 x i8] c">> [TCP] INITIATING GHOST-BREAKER...\0A\00", align 8
@.sc.498 = global i64 0
@.sc.499 = global i64 0
@.sc.500 = global i64 0
@.str.501 = private unnamed_addr constant [51 x i8] c">> [TCP] SYN-ACK SECURED! FINALIZING HANDSHAKE...\0A\00", align 8
@.str.502 = private unnamed_addr constant [54 x i8] c">> [HTTP] ROUTE ESTABLISHED. TRANSMITTING 'GET /'...\0A\00", align 8
@.sc.503 = global i64 0
@.sc.504 = global i64 0
@.str.505 = private unnamed_addr constant [37 x i8] c">> [HTTP] 200 OK! SERVER RESPONDED.\0A\00", align 8
@.str.506 = private unnamed_addr constant [50 x i8] c">> [HTTP] PAYLOAD PREVIEW:\0A---------------------\0A\00", align 8
@.sc.507 = global i64 0
@.sc.508 = global i64 0
@.sc.509 = global i64 0
@.str.510 = private unnamed_addr constant [33 x i8] c"\0A...[EOF]\0A---------------------\0A\00", align 8
@.str.511 = private unnamed_addr constant [37 x i8] c">> [ERR] RX TIMEOUT. NO HTTP REPLY.\0A\00", align 8
@.str.512 = private unnamed_addr constant [41 x i8] c">> [ERR] CONNECTION RESET (RST). FLAGS: \00", align 8
@.str.513 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.514 = private unnamed_addr constant [49 x i8] c">> [ERR] ROUTER RETURNED NON-TCP PACKET. PROTO: \00", align 8
@.str.515 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.516 = private unnamed_addr constant [41 x i8] c">> [ERR] RX TIMEOUT. NO SYN-ACK CAUGHT.\0A\00", align 8
@.str.517 = private unnamed_addr constant [13 x i8] c">> TX DUMP: \00", align 8
@.str.518 = private unnamed_addr constant [2 x i8] c" \00", align 8
@.str.519 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.520 = private unnamed_addr constant [6 x i8] c"close\00", align 8
@.str.521 = private unnamed_addr constant [10 x i8] c"Unknown: \00", align 8
@.str.522 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.523 = private unnamed_addr constant [10 x i8] c"identitas\00", align 8
@.str.524 = private unnamed_addr constant [6 x i8] c"root\0A\00", align 8
@.str.525 = private unnamed_addr constant [10 x i8] c"enumerare\00", align 8
@.str.526 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.527 = private unnamed_addr constant [10 x i8] c"revelare \00", align 8
@.str.528 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.529 = private unnamed_addr constant [6 x i8] c"exire\00", align 8
@.str.530 = private unnamed_addr constant [12 x i8] c">> Exited.\0A\00", align 8
@.str.531 = private unnamed_addr constant [9 x i8] c"Ignota: \00", align 8
@.str.532 = private unnamed_addr constant [2 x i8] c"\0A\00", align 8
@.str.533 = private unnamed_addr constant [3 x i8] c":q\00", align 8
@.str.534 = private unnamed_addr constant [19 x i8] c">> Exited editor.\0A\00", align 8
@.str.535 = private unnamed_addr constant [3 x i8] c":w\00", align 8
@.str.536 = private unnamed_addr constant [10 x i8] c">> Saved \00", align 8
@.str.537 = private unnamed_addr constant [3 x i8] c" (\00", align 8
@.str.538 = private unnamed_addr constant [5 x i8] c" B)\0A\00", align 8
@.str.539 = private unnamed_addr constant [4 x i8] c":wq\00", align 8
@.str.540 = private unnamed_addr constant [22 x i8] c">> Saved and exited.\0A\00", align 8
@.str.541 = private unnamed_addr constant [3 x i8] c":p\00", align 8
@.str.542 = private unnamed_addr constant [4 x i8] c"-- \00", align 8
@.str.543 = private unnamed_addr constant [5 x i8] c" --\0A\00", align 8
@.str.544 = private unnamed_addr constant [19 x i8] c"\0A----------------\0A\00", align 8
@.sc.545 = global i64 0
@.str.546 = private unnamed_addr constant [5 x i8] c"IPC:\00", align 8
@.str.547 = private unnamed_addr constant [3 x i8] c"> \00", align 8
@.str.548 = private unnamed_addr constant [18 x i8] c"[root::ACHLYS]~> \00", align 8
@.str.549 = private unnamed_addr constant [10 x i8] c"[EDIT]~> \00", align 8
@.str.550 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.551 = private unnamed_addr constant [5 x i8] c"IPC:\00", align 8
@.sc.552 = global i64 0
@.sc.553 = global i64 0
@.sc.554 = global i64 0
@.sc.555 = global i64 0
@.sc.556 = global i64 0
@.sc.557 = global i64 0
@.sc.558 = global i64 0
@.sc.559 = global i64 0
@.sc.560 = global i64 0
@.sc.561 = global i64 0
@.sc.562 = global i64 0
@.sc.563 = global i64 0
@.sc.564 = global i64 0
@.sc.565 = global i64 0
@.sc.566 = global i64 0
@.sc.567 = global i64 0
@.sc.568 = global i64 0
@.sc.569 = global i64 0
@.str.570 = private unnamed_addr constant [31 x i8] c"ROOT TERMINAL\0A-------------\0A> \00", align 8
@.str.571 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.572 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.573 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.574 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.575 = private unnamed_addr constant [31 x i8] c"ROOT TERMINAL\0A-------------\0A> \00", align 8
@.str.576 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.577 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.578 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.579 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.580 = private unnamed_addr constant [36 x i8] c">> PARADIGM SHIFT: ORDER INITIATED.\00", align 8
@.str.581 = private unnamed_addr constant [40 x i8] c">> PARADIGM SHIFT: CHAOS VOID UNLOCKED.\00", align 8
@.sc.582 = global i64 0
@.sc.583 = global i64 0
@.sc.584 = global i64 0
@.sc.585 = global i64 0
@.str.586 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.587 = private unnamed_addr constant [10 x i8] c"BACKSPACE\00", align 8
@.str.588 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.589 = private unnamed_addr constant [6 x i8] c"ENTER\00", align 8
@.str.590 = private unnamed_addr constant [6 x i8] c"spawn\00", align 8
@.sc.591 = global i64 0
@.str.592 = private unnamed_addr constant [31 x i8] c"ROOT TERMINAL\0A-------------\0A> \00", align 8
@.str.593 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.594 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.595 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.596 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.597 = private unnamed_addr constant [31 x i8] c"ROOT TERMINAL\0A-------------\0A> \00", align 8
@.str.598 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.599 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.600 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.601 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.602 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.sc.603 = global i64 0
@.str.604 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.605 = private unnamed_addr constant [4 x i8] c"ESC\00", align 8
@.str.606 = private unnamed_addr constant [2 x i8] c"1\00", align 8
@.str.607 = private unnamed_addr constant [2 x i8] c"2\00", align 8
@.str.608 = private unnamed_addr constant [2 x i8] c"3\00", align 8
@.str.609 = private unnamed_addr constant [2 x i8] c"4\00", align 8
@.str.610 = private unnamed_addr constant [2 x i8] c"5\00", align 8
@.str.611 = private unnamed_addr constant [2 x i8] c"6\00", align 8
@.str.612 = private unnamed_addr constant [2 x i8] c"7\00", align 8
@.str.613 = private unnamed_addr constant [2 x i8] c"8\00", align 8
@.str.614 = private unnamed_addr constant [2 x i8] c"9\00", align 8
@.str.615 = private unnamed_addr constant [2 x i8] c"0\00", align 8
@.str.616 = private unnamed_addr constant [2 x i8] c"-\00", align 8
@.str.617 = private unnamed_addr constant [2 x i8] c"=\00", align 8
@.str.618 = private unnamed_addr constant [10 x i8] c"BACKSPACE\00", align 8
@.str.619 = private unnamed_addr constant [4 x i8] c"TAB\00", align 8
@.str.620 = private unnamed_addr constant [2 x i8] c"q\00", align 8
@.str.621 = private unnamed_addr constant [2 x i8] c"w\00", align 8
@.str.622 = private unnamed_addr constant [2 x i8] c"e\00", align 8
@.str.623 = private unnamed_addr constant [2 x i8] c"r\00", align 8
@.str.624 = private unnamed_addr constant [2 x i8] c"t\00", align 8
@.str.625 = private unnamed_addr constant [2 x i8] c"y\00", align 8
@.str.626 = private unnamed_addr constant [2 x i8] c"u\00", align 8
@.str.627 = private unnamed_addr constant [2 x i8] c"i\00", align 8
@.str.628 = private unnamed_addr constant [2 x i8] c"o\00", align 8
@.str.629 = private unnamed_addr constant [2 x i8] c"p\00", align 8
@.str.630 = private unnamed_addr constant [2 x i8] c"[\00", align 8
@.str.631 = private unnamed_addr constant [2 x i8] c"]\00", align 8
@.str.632 = private unnamed_addr constant [6 x i8] c"ENTER\00", align 8
@.str.633 = private unnamed_addr constant [5 x i8] c"CTRL\00", align 8
@.str.634 = private unnamed_addr constant [2 x i8] c"a\00", align 8
@.str.635 = private unnamed_addr constant [2 x i8] c"s\00", align 8
@.str.636 = private unnamed_addr constant [2 x i8] c"d\00", align 8
@.str.637 = private unnamed_addr constant [2 x i8] c"f\00", align 8
@.str.638 = private unnamed_addr constant [2 x i8] c"g\00", align 8
@.str.639 = private unnamed_addr constant [2 x i8] c"h\00", align 8
@.str.640 = private unnamed_addr constant [2 x i8] c"j\00", align 8
@.str.641 = private unnamed_addr constant [2 x i8] c"k\00", align 8
@.str.642 = private unnamed_addr constant [2 x i8] c"l\00", align 8
@.str.643 = private unnamed_addr constant [2 x i8] c";\00", align 8
@.str.644 = private unnamed_addr constant [2 x i8] c"'\00", align 8
@.str.645 = private unnamed_addr constant [2 x i8] c"`\00", align 8
@.str.646 = private unnamed_addr constant [7 x i8] c"LSHIFT\00", align 8
@.str.647 = private unnamed_addr constant [2 x i8] c"\5C\00", align 8
@.str.648 = private unnamed_addr constant [2 x i8] c"z\00", align 8
@.str.649 = private unnamed_addr constant [2 x i8] c"x\00", align 8
@.str.650 = private unnamed_addr constant [2 x i8] c"c\00", align 8
@.str.651 = private unnamed_addr constant [2 x i8] c"v\00", align 8
@.str.652 = private unnamed_addr constant [2 x i8] c"b\00", align 8
@.str.653 = private unnamed_addr constant [2 x i8] c"n\00", align 8
@.str.654 = private unnamed_addr constant [2 x i8] c"m\00", align 8
@.str.655 = private unnamed_addr constant [2 x i8] c",\00", align 8
@.str.656 = private unnamed_addr constant [2 x i8] c".\00", align 8
@.str.657 = private unnamed_addr constant [2 x i8] c"/\00", align 8
@.str.658 = private unnamed_addr constant [7 x i8] c"RSHIFT\00", align 8
@.str.659 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.str.660 = private unnamed_addr constant [4 x i8] c"ALT\00", align 8
@.str.661 = private unnamed_addr constant [2 x i8] c" \00", align 8
@.str.662 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.663 = private unnamed_addr constant [4 x i8] c"ESC\00", align 8
@.str.664 = private unnamed_addr constant [2 x i8] c"!\00", align 8
@.str.665 = private unnamed_addr constant [2 x i8] c"@\00", align 8
@.str.666 = private unnamed_addr constant [2 x i8] c"#\00", align 8
@.str.667 = private unnamed_addr constant [2 x i8] c"$\00", align 8
@.str.668 = private unnamed_addr constant [2 x i8] c"%\00", align 8
@.str.669 = private unnamed_addr constant [2 x i8] c"^\00", align 8
@.str.670 = private unnamed_addr constant [2 x i8] c"&\00", align 8
@.str.671 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.str.672 = private unnamed_addr constant [2 x i8] c"(\00", align 8
@.str.673 = private unnamed_addr constant [2 x i8] c")\00", align 8
@.str.674 = private unnamed_addr constant [2 x i8] c"_\00", align 8
@.str.675 = private unnamed_addr constant [2 x i8] c"+\00", align 8
@.str.676 = private unnamed_addr constant [10 x i8] c"BACKSPACE\00", align 8
@.str.677 = private unnamed_addr constant [4 x i8] c"TAB\00", align 8
@.str.678 = private unnamed_addr constant [2 x i8] c"Q\00", align 8
@.str.679 = private unnamed_addr constant [2 x i8] c"W\00", align 8
@.str.680 = private unnamed_addr constant [2 x i8] c"E\00", align 8
@.str.681 = private unnamed_addr constant [2 x i8] c"R\00", align 8
@.str.682 = private unnamed_addr constant [2 x i8] c"T\00", align 8
@.str.683 = private unnamed_addr constant [2 x i8] c"Y\00", align 8
@.str.684 = private unnamed_addr constant [2 x i8] c"U\00", align 8
@.str.685 = private unnamed_addr constant [2 x i8] c"I\00", align 8
@.str.686 = private unnamed_addr constant [2 x i8] c"O\00", align 8
@.str.687 = private unnamed_addr constant [2 x i8] c"P\00", align 8
@.str.688 = private unnamed_addr constant [2 x i8] c"{\00", align 8
@.str.689 = private unnamed_addr constant [2 x i8] c"}\00", align 8
@.str.690 = private unnamed_addr constant [6 x i8] c"ENTER\00", align 8
@.str.691 = private unnamed_addr constant [5 x i8] c"CTRL\00", align 8
@.str.692 = private unnamed_addr constant [2 x i8] c"A\00", align 8
@.str.693 = private unnamed_addr constant [2 x i8] c"S\00", align 8
@.str.694 = private unnamed_addr constant [2 x i8] c"D\00", align 8
@.str.695 = private unnamed_addr constant [2 x i8] c"F\00", align 8
@.str.696 = private unnamed_addr constant [2 x i8] c"G\00", align 8
@.str.697 = private unnamed_addr constant [2 x i8] c"H\00", align 8
@.str.698 = private unnamed_addr constant [2 x i8] c"J\00", align 8
@.str.699 = private unnamed_addr constant [2 x i8] c"K\00", align 8
@.str.700 = private unnamed_addr constant [2 x i8] c"L\00", align 8
@.str.701 = private unnamed_addr constant [2 x i8] c":\00", align 8
@.str.702 = private unnamed_addr constant [2 x i8] c"\22\00", align 8
@.str.703 = private unnamed_addr constant [2 x i8] c"~\00", align 8
@.str.704 = private unnamed_addr constant [7 x i8] c"LSHIFT\00", align 8
@.str.705 = private unnamed_addr constant [2 x i8] c"|\00", align 8
@.str.706 = private unnamed_addr constant [2 x i8] c"Z\00", align 8
@.str.707 = private unnamed_addr constant [2 x i8] c"X\00", align 8
@.str.708 = private unnamed_addr constant [2 x i8] c"C\00", align 8
@.str.709 = private unnamed_addr constant [2 x i8] c"V\00", align 8
@.str.710 = private unnamed_addr constant [2 x i8] c"B\00", align 8
@.str.711 = private unnamed_addr constant [2 x i8] c"N\00", align 8
@.str.712 = private unnamed_addr constant [2 x i8] c"M\00", align 8
@.str.713 = private unnamed_addr constant [2 x i8] c"<\00", align 8
@.str.714 = private unnamed_addr constant [2 x i8] c">\00", align 8
@.str.715 = private unnamed_addr constant [2 x i8] c"?\00", align 8
@.str.716 = private unnamed_addr constant [7 x i8] c"RSHIFT\00", align 8
@.str.717 = private unnamed_addr constant [2 x i8] c"*\00", align 8
@.str.718 = private unnamed_addr constant [4 x i8] c"ALT\00", align 8
@.str.719 = private unnamed_addr constant [2 x i8] c" \00", align 8
@.str.720 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.721 = private unnamed_addr constant [1 x i8] c"\00", align 8
@.str.722 = private unnamed_addr constant [1 x i8] c"\00", align 8
define i64 @malloc(i64 %arg_size) {
  %ptr_size = alloca i64
  store i64 %arg_size, i64* %ptr_size
  %ptr_rem = alloca i64
  %ptr_allocated_ptr = alloca i64
  %r1 = load i64, i64* @kernel_heap
  %r2 = srem i64 %r1, 16
  store i64 %r2, i64* %ptr_rem
  %r3 = load i64, i64* %ptr_rem
  %r5 = icmp sgt i64 %r3, 0
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L1, label %L3
L1:
  %r7 = load i64, i64* @kernel_heap
  %r8 = load i64, i64* %ptr_rem
  %r9 = sub i64 16, %r8
  %r10 = add i64 %r7, %r9
  store i64 %r10, i64* @kernel_heap
  br label %L3
L3:
  %r11 = load i64, i64* @kernel_heap
  store i64 %r11, i64* %ptr_allocated_ptr
  %r12 = load i64, i64* @kernel_heap
  %r13 = load i64, i64* %ptr_size
  %r14 = add i64 %r12, %r13
  store i64 %r14, i64* @kernel_heap
  %r15 = load i64, i64* %ptr_allocated_ptr
  ret i64 %r15
  ret i64 0
}
define i64 @realloc(i64 %arg_ptr, i64 %arg_size) {
  %ptr_ptr = alloca i64
  store i64 %arg_ptr, i64* %ptr_ptr
  %ptr_size = alloca i64
  store i64 %arg_size, i64* %ptr_size
  %ptr_new_ptr = alloca i64
  %ptr_old_size = alloca i64
  %ptr_i = alloca i64
  %ptr_b = alloca i64
  %r1 = load i64, i64* %ptr_size
  %r2 = call i64 @malloc(i64 %r1)
  store i64 %r2, i64* %ptr_new_ptr
  %r3 = load i64, i64* %ptr_ptr
  %r5 = icmp sgt i64 %r3, 0
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L4, label %L6
L4:
  %r7 = load i64, i64* %ptr_size
  %r8 = sub i64 %r7, 8
  store i64 %r8, i64* %ptr_old_size
  store i64 0, i64* %ptr_i
  br label %L7
L7:
  %r9 = load i64, i64* %ptr_i
  %r10 = load i64, i64* %ptr_old_size
  %r12 = icmp slt i64 %r9, %r10
  %r11 = zext i1 %r12 to i64
  %r13 = icmp ne i64 %r11, 0
  br i1 %r13, label %L8, label %L9
L8:
  %r14 = load i64, i64* %ptr_ptr
  %r15 = load i64, i64* %ptr_i
  %r16 = add i64 %r14, %r15
  %r17 = inttoptr i64 %r16 to ptr
  %r18 = load volatile i8, ptr %r17
  %r19 = zext i8 %r18 to i64
  store i64 %r19, i64* %ptr_b
  %r20 = load i64, i64* %ptr_new_ptr
  %r21 = load i64, i64* %ptr_i
  %r22 = add i64 %r20, %r21
  %r23 = load i64, i64* %ptr_b
  %r24 = inttoptr i64 %r22 to ptr
  %r25 = trunc i64 %r23 to i8
  store volatile i8 %r25, ptr %r24
  %r26 = load i64, i64* %ptr_i
  %r27 = call i64 @_add(i64 %r26, i64 1)
  store i64 %r27, i64* %ptr_i
  br label %L7
L9:
  br label %L6
L6:
  %r28 = load i64, i64* %ptr_new_ptr
  ret i64 %r28
  ret i64 0
}
define i64 @read_32(i64 %arg_addr) {
  %ptr_addr = alloca i64
  store i64 %arg_addr, i64* %ptr_addr
  %ptr_b0 = alloca i64
  %ptr_b1 = alloca i64
  %ptr_b2 = alloca i64
  %ptr_b3 = alloca i64
  %r1 = load i64, i64* %ptr_addr
  %r2 = inttoptr i64 %r1 to ptr
  %r3 = load volatile i8, ptr %r2
  %r4 = zext i8 %r3 to i64
  store i64 %r4, i64* %ptr_b0
  %r5 = load i64, i64* %ptr_addr
  %r6 = add i64 %r5, 1
  %r7 = inttoptr i64 %r6 to ptr
  %r8 = load volatile i8, ptr %r7
  %r9 = zext i8 %r8 to i64
  store i64 %r9, i64* %ptr_b1
  %r10 = load i64, i64* %ptr_addr
  %r11 = add i64 %r10, 2
  %r12 = inttoptr i64 %r11 to ptr
  %r13 = load volatile i8, ptr %r12
  %r14 = zext i8 %r13 to i64
  store i64 %r14, i64* %ptr_b2
  %r15 = load i64, i64* %ptr_addr
  %r16 = add i64 %r15, 3
  %r17 = inttoptr i64 %r16 to ptr
  %r18 = load volatile i8, ptr %r17
  %r19 = zext i8 %r18 to i64
  store i64 %r19, i64* %ptr_b3
  %r20 = load i64, i64* %ptr_b0
  %r21 = load i64, i64* %ptr_b1
  %r22 = shl i64 %r21, 8
  %r23 = or i64 %r20, %r22
  %r24 = load i64, i64* %ptr_b2
  %r25 = shl i64 %r24, 16
  %r26 = or i64 %r23, %r25
  %r27 = load i64, i64* %ptr_b3
  %r28 = shl i64 %r27, 24
  %r29 = or i64 %r26, %r28
  ret i64 %r29
  ret i64 0
}
define i64 @init_graphics() {
  %r1 = call i64 @read_32(i64 20480)
  store i64 %r1, i64* @FB_ADDR
  %r2 = call i64 @read_32(i64 20484)
  store i64 %r2, i64* @FB_PITCH
  %r3 = call i64 @read_32(i64 20488)
  store i64 %r3, i64* @FB_WIDTH
  %r4 = call i64 @read_32(i64 20492)
  store i64 %r4, i64* @FB_HEIGHT
  %r5 = load i64, i64* @FB_HEIGHT
  %r6 = load i64, i64* @FB_PITCH
  %r7 = mul i64 %r5, %r6
  %r8 = call i64 @malloc(i64 %r7)
  store i64 %r8, i64* @BACK_BUFFER
  ret i64 0
}
define i64 @put_pixel(i64 %arg_x, i64 %arg_y, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_x = alloca i64
  store i64 %arg_x, i64* %ptr_x
  %ptr_y = alloca i64
  store i64 %arg_y, i64* %ptr_y
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_offset = alloca i64
  %ptr_addr = alloca i64
  %r1 = load i64, i64* %ptr_x
  %r3 = icmp sge i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  store i64 0, i64* @.sc.3
  %r5 = icmp ne i64 %r2, 0
  br i1 %r5, label %L10, label %L11
L10:
  %r6 = load i64, i64* %ptr_x
  %r7 = load i64, i64* @FB_WIDTH
  %r9 = icmp slt i64 %r6, %r7
  %r8 = zext i1 %r9 to i64
  %r10 = icmp ne i64 %r8, 0
  %r11 = zext i1 %r10 to i64
  store i64 %r11, i64* @.sc.3
  br label %L11
L11:
  %r4 = load i64, i64* @.sc.3
  store i64 0, i64* @.sc.2
  %r13 = icmp ne i64 %r4, 0
  br i1 %r13, label %L12, label %L13
L12:
  %r14 = load i64, i64* %ptr_y
  %r16 = icmp sge i64 %r14, 0
  %r15 = zext i1 %r16 to i64
  %r17 = icmp ne i64 %r15, 0
  %r18 = zext i1 %r17 to i64
  store i64 %r18, i64* @.sc.2
  br label %L13
L13:
  %r12 = load i64, i64* @.sc.2
  store i64 0, i64* @.sc.1
  %r20 = icmp ne i64 %r12, 0
  br i1 %r20, label %L14, label %L15
L14:
  %r21 = load i64, i64* %ptr_y
  %r22 = load i64, i64* @FB_HEIGHT
  %r24 = icmp slt i64 %r21, %r22
  %r23 = zext i1 %r24 to i64
  %r25 = icmp ne i64 %r23, 0
  %r26 = zext i1 %r25 to i64
  store i64 %r26, i64* @.sc.1
  br label %L15
L15:
  %r19 = load i64, i64* @.sc.1
  %r27 = icmp ne i64 %r19, 0
  br i1 %r27, label %L16, label %L18
L16:
  %r28 = load i64, i64* %ptr_y
  %r29 = load i64, i64* @FB_PITCH
  %r30 = mul i64 %r28, %r29
  %r31 = load i64, i64* %ptr_x
  %r32 = mul i64 %r31, 4
  %r33 = add i64 %r30, %r32
  store i64 %r33, i64* %ptr_offset
  %r34 = load i64, i64* @BACK_BUFFER
  %r35 = load i64, i64* %ptr_offset
  %r36 = add i64 %r34, %r35
  store i64 %r36, i64* %ptr_addr
  %r37 = load i64, i64* %ptr_addr
  %r38 = load i64, i64* %ptr_b
  %r39 = inttoptr i64 %r37 to ptr
  %r40 = trunc i64 %r38 to i8
  store volatile i8 %r40, ptr %r39
  %r41 = load i64, i64* %ptr_addr
  %r42 = add i64 %r41, 1
  %r43 = load i64, i64* %ptr_g
  %r44 = inttoptr i64 %r42 to ptr
  %r45 = trunc i64 %r43 to i8
  store volatile i8 %r45, ptr %r44
  %r46 = load i64, i64* %ptr_addr
  %r47 = add i64 %r46, 2
  %r48 = load i64, i64* %ptr_r
  %r49 = inttoptr i64 %r47 to ptr
  %r50 = trunc i64 %r48 to i8
  store volatile i8 %r50, ptr %r49
  br label %L18
L18:
  ret i64 0
}
define i64 @swap_buffers() {
  %r1 = load i64, i64* @FB_ADDR
  %r2 = load i64, i64* @BACK_BUFFER
  %r3 = load i64, i64* @FB_HEIGHT
  %r4 = load i64, i64* @FB_PITCH
  %r5 = mul i64 %r3, %r4
  %r6 = call i64 @fast_memcpy(i64 %r1, i64 %r2, i64 %r5)
  ret i64 0
}
define i64 @abs(i64 %arg_n) {
  %ptr_n = alloca i64
  store i64 %arg_n, i64* %ptr_n
  %r1 = load i64, i64* %ptr_n
  %r3 = icmp slt i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  %r4 = icmp ne i64 %r2, 0
  br i1 %r4, label %L19, label %L21
L19:
  %r5 = load i64, i64* %ptr_n
  %r6 = sub i64 0, %r5
  ret i64 %r6
  br label %L21
L21:
  %r7 = load i64, i64* %ptr_n
  ret i64 %r7
  ret i64 0
}
define i64 @draw_line(i64 %arg_x0, i64 %arg_y0, i64 %arg_x1, i64 %arg_y1, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_x0 = alloca i64
  store i64 %arg_x0, i64* %ptr_x0
  %ptr_y0 = alloca i64
  store i64 %arg_y0, i64* %ptr_y0
  %ptr_x1 = alloca i64
  store i64 %arg_x1, i64* %ptr_x1
  %ptr_y1 = alloca i64
  store i64 %arg_y1, i64* %ptr_y1
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_dx = alloca i64
  %ptr_dy = alloca i64
  %ptr_sx = alloca i64
  %ptr_sy = alloca i64
  %ptr_err = alloca i64
  %ptr_running = alloca i64
  %ptr_e2 = alloca i64
  %r1 = load i64, i64* %ptr_x1
  %r2 = load i64, i64* %ptr_x0
  %r3 = sub i64 %r1, %r2
  %r4 = call i64 @abs(i64 %r3)
  store i64 %r4, i64* %ptr_dx
  %r5 = load i64, i64* %ptr_y1
  %r6 = load i64, i64* %ptr_y0
  %r7 = sub i64 %r5, %r6
  %r8 = call i64 @abs(i64 %r7)
  %r9 = sub i64 0, %r8
  store i64 %r9, i64* %ptr_dy
  %r10 = sub i64 0, 1
  store i64 %r10, i64* %ptr_sx
  %r11 = load i64, i64* %ptr_x0
  %r12 = load i64, i64* %ptr_x1
  %r14 = icmp slt i64 %r11, %r12
  %r13 = zext i1 %r14 to i64
  %r15 = icmp ne i64 %r13, 0
  br i1 %r15, label %L22, label %L24
L22:
  store i64 1, i64* %ptr_sx
  br label %L24
L24:
  %r16 = sub i64 0, 1
  store i64 %r16, i64* %ptr_sy
  %r17 = load i64, i64* %ptr_y0
  %r18 = load i64, i64* %ptr_y1
  %r20 = icmp slt i64 %r17, %r18
  %r19 = zext i1 %r20 to i64
  %r21 = icmp ne i64 %r19, 0
  br i1 %r21, label %L25, label %L27
L25:
  store i64 1, i64* %ptr_sy
  br label %L27
L27:
  %r22 = load i64, i64* %ptr_dx
  %r23 = load i64, i64* %ptr_dy
  %r24 = call i64 @_add(i64 %r22, i64 %r23)
  store i64 %r24, i64* %ptr_err
  store i64 1, i64* %ptr_running
  br label %L28
L28:
  %r25 = load i64, i64* %ptr_running
  %r26 = icmp ne i64 %r25, 0
  br i1 %r26, label %L29, label %L30
L29:
  %r27 = load i64, i64* %ptr_x0
  %r29 = icmp sge i64 %r27, 0
  %r28 = zext i1 %r29 to i64
  store i64 0, i64* @.sc.6
  %r31 = icmp ne i64 %r28, 0
  br i1 %r31, label %L31, label %L32
L31:
  %r32 = load i64, i64* %ptr_x0
  %r33 = load i64, i64* @FB_WIDTH
  %r35 = icmp slt i64 %r32, %r33
  %r34 = zext i1 %r35 to i64
  %r36 = icmp ne i64 %r34, 0
  %r37 = zext i1 %r36 to i64
  store i64 %r37, i64* @.sc.6
  br label %L32
L32:
  %r30 = load i64, i64* @.sc.6
  store i64 0, i64* @.sc.5
  %r39 = icmp ne i64 %r30, 0
  br i1 %r39, label %L33, label %L34
L33:
  %r40 = load i64, i64* %ptr_y0
  %r42 = icmp sge i64 %r40, 0
  %r41 = zext i1 %r42 to i64
  %r43 = icmp ne i64 %r41, 0
  %r44 = zext i1 %r43 to i64
  store i64 %r44, i64* @.sc.5
  br label %L34
L34:
  %r38 = load i64, i64* @.sc.5
  store i64 0, i64* @.sc.4
  %r46 = icmp ne i64 %r38, 0
  br i1 %r46, label %L35, label %L36
L35:
  %r47 = load i64, i64* %ptr_y0
  %r48 = load i64, i64* @FB_HEIGHT
  %r50 = icmp slt i64 %r47, %r48
  %r49 = zext i1 %r50 to i64
  %r51 = icmp ne i64 %r49, 0
  %r52 = zext i1 %r51 to i64
  store i64 %r52, i64* @.sc.4
  br label %L36
L36:
  %r45 = load i64, i64* @.sc.4
  %r53 = icmp ne i64 %r45, 0
  br i1 %r53, label %L37, label %L39
L37:
  %r54 = load i64, i64* %ptr_x0
  %r55 = load i64, i64* %ptr_y0
  %r56 = load i64, i64* %ptr_r
  %r57 = load i64, i64* %ptr_g
  %r58 = load i64, i64* %ptr_b
  %r59 = call i64 @put_pixel(i64 %r54, i64 %r55, i64 %r56, i64 %r57, i64 %r58)
  br label %L39
L39:
  %r60 = load i64, i64* %ptr_x0
  %r61 = load i64, i64* %ptr_x1
  %r62 = call i64 @_eq(i64 %r60, i64 %r61)
  store i64 0, i64* @.sc.7
  %r64 = icmp ne i64 %r62, 0
  br i1 %r64, label %L40, label %L41
L40:
  %r65 = load i64, i64* %ptr_y0
  %r66 = load i64, i64* %ptr_y1
  %r67 = call i64 @_eq(i64 %r65, i64 %r66)
  %r68 = icmp ne i64 %r67, 0
  %r69 = zext i1 %r68 to i64
  store i64 %r69, i64* @.sc.7
  br label %L41
L41:
  %r63 = load i64, i64* @.sc.7
  %r70 = icmp ne i64 %r63, 0
  br i1 %r70, label %L42, label %L44
L42:
  store i64 0, i64* %ptr_running
  br label %L44
L44:
  %r71 = load i64, i64* %ptr_running
  %r72 = icmp ne i64 %r71, 0
  br i1 %r72, label %L45, label %L47
L45:
  %r73 = load i64, i64* %ptr_err
  %r74 = mul i64 2, %r73
  store i64 %r74, i64* %ptr_e2
  %r75 = load i64, i64* %ptr_e2
  %r76 = load i64, i64* %ptr_dy
  %r78 = icmp sge i64 %r75, %r76
  %r77 = zext i1 %r78 to i64
  %r79 = icmp ne i64 %r77, 0
  br i1 %r79, label %L48, label %L50
L48:
  %r80 = load i64, i64* %ptr_err
  %r81 = load i64, i64* %ptr_dy
  %r82 = call i64 @_add(i64 %r80, i64 %r81)
  store i64 %r82, i64* %ptr_err
  %r83 = load i64, i64* %ptr_x0
  %r84 = load i64, i64* %ptr_sx
  %r85 = call i64 @_add(i64 %r83, i64 %r84)
  store i64 %r85, i64* %ptr_x0
  br label %L50
L50:
  %r86 = load i64, i64* %ptr_e2
  %r87 = load i64, i64* %ptr_dx
  %r89 = icmp sle i64 %r86, %r87
  %r88 = zext i1 %r89 to i64
  %r90 = icmp ne i64 %r88, 0
  br i1 %r90, label %L51, label %L53
L51:
  %r91 = load i64, i64* %ptr_err
  %r92 = load i64, i64* %ptr_dx
  %r93 = call i64 @_add(i64 %r91, i64 %r92)
  store i64 %r93, i64* %ptr_err
  %r94 = load i64, i64* %ptr_y0
  %r95 = load i64, i64* %ptr_sy
  %r96 = call i64 @_add(i64 %r94, i64 %r95)
  store i64 %r96, i64* %ptr_y0
  br label %L53
L53:
  br label %L47
L47:
  br label %L28
L30:
  ret i64 0
}
define i64 @draw_rect(i64 %arg_x, i64 %arg_y, i64 %arg_w, i64 %arg_h, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_x = alloca i64
  store i64 %arg_x, i64* %ptr_x
  %ptr_y = alloca i64
  store i64 %arg_y, i64* %ptr_y
  %ptr_w = alloca i64
  store i64 %arg_w, i64* %ptr_w
  %ptr_h = alloca i64
  store i64 %arg_h, i64* %ptr_h
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_color = alloca i64
  %ptr_start_x = alloca i64
  %ptr_start_y = alloca i64
  %ptr_end_x = alloca i64
  %ptr_end_y = alloca i64
  %ptr_draw_w = alloca i64
  %ptr_draw_h = alloca i64
  %ptr_j = alloca i64
  %ptr_current_y = alloca i64
  %ptr_offset = alloca i64
  %ptr_row_addr = alloca i64
  %r1 = load i64, i64* %ptr_b
  %r2 = load i64, i64* %ptr_g
  %r3 = shl i64 %r2, 8
  %r4 = or i64 %r1, %r3
  %r5 = load i64, i64* %ptr_r
  %r6 = shl i64 %r5, 16
  %r7 = or i64 %r4, %r6
  store i64 %r7, i64* %ptr_color
  %r8 = load i64, i64* %ptr_x
  store i64 %r8, i64* %ptr_start_x
  %r9 = load i64, i64* %ptr_start_x
  %r11 = icmp slt i64 %r9, 0
  %r10 = zext i1 %r11 to i64
  %r12 = icmp ne i64 %r10, 0
  br i1 %r12, label %L54, label %L56
L54:
  store i64 0, i64* %ptr_start_x
  br label %L56
L56:
  %r13 = load i64, i64* %ptr_y
  store i64 %r13, i64* %ptr_start_y
  %r14 = load i64, i64* %ptr_start_y
  %r16 = icmp slt i64 %r14, 0
  %r15 = zext i1 %r16 to i64
  %r17 = icmp ne i64 %r15, 0
  br i1 %r17, label %L57, label %L59
L57:
  store i64 0, i64* %ptr_start_y
  br label %L59
L59:
  %r18 = load i64, i64* %ptr_x
  %r19 = load i64, i64* %ptr_w
  %r20 = call i64 @_add(i64 %r18, i64 %r19)
  store i64 %r20, i64* %ptr_end_x
  %r21 = load i64, i64* %ptr_end_x
  %r22 = load i64, i64* @FB_WIDTH
  %r24 = icmp sgt i64 %r21, %r22
  %r23 = zext i1 %r24 to i64
  %r25 = icmp ne i64 %r23, 0
  br i1 %r25, label %L60, label %L62
L60:
  %r26 = load i64, i64* @FB_WIDTH
  store i64 %r26, i64* %ptr_end_x
  br label %L62
L62:
  %r27 = load i64, i64* %ptr_y
  %r28 = load i64, i64* %ptr_h
  %r29 = call i64 @_add(i64 %r27, i64 %r28)
  store i64 %r29, i64* %ptr_end_y
  %r30 = load i64, i64* %ptr_end_y
  %r31 = load i64, i64* @FB_HEIGHT
  %r33 = icmp sgt i64 %r30, %r31
  %r32 = zext i1 %r33 to i64
  %r34 = icmp ne i64 %r32, 0
  br i1 %r34, label %L63, label %L65
L63:
  %r35 = load i64, i64* @FB_HEIGHT
  store i64 %r35, i64* %ptr_end_y
  br label %L65
L65:
  %r36 = load i64, i64* %ptr_end_x
  %r37 = load i64, i64* %ptr_start_x
  %r38 = sub i64 %r36, %r37
  store i64 %r38, i64* %ptr_draw_w
  %r39 = load i64, i64* %ptr_end_y
  %r40 = load i64, i64* %ptr_start_y
  %r41 = sub i64 %r39, %r40
  store i64 %r41, i64* %ptr_draw_h
  %r42 = load i64, i64* %ptr_draw_w
  %r44 = icmp sgt i64 %r42, 0
  %r43 = zext i1 %r44 to i64
  store i64 0, i64* @.sc.8
  %r46 = icmp ne i64 %r43, 0
  br i1 %r46, label %L66, label %L67
L66:
  %r47 = load i64, i64* %ptr_draw_h
  %r49 = icmp sgt i64 %r47, 0
  %r48 = zext i1 %r49 to i64
  %r50 = icmp ne i64 %r48, 0
  %r51 = zext i1 %r50 to i64
  store i64 %r51, i64* @.sc.8
  br label %L67
L67:
  %r45 = load i64, i64* @.sc.8
  %r52 = icmp ne i64 %r45, 0
  br i1 %r52, label %L68, label %L70
L68:
  store i64 0, i64* %ptr_j
  br label %L71
L71:
  %r53 = load i64, i64* %ptr_j
  %r54 = load i64, i64* %ptr_draw_h
  %r56 = icmp slt i64 %r53, %r54
  %r55 = zext i1 %r56 to i64
  %r57 = icmp ne i64 %r55, 0
  br i1 %r57, label %L72, label %L73
L72:
  %r58 = load i64, i64* %ptr_start_y
  %r59 = load i64, i64* %ptr_j
  %r60 = call i64 @_add(i64 %r58, i64 %r59)
  store i64 %r60, i64* %ptr_current_y
  %r61 = load i64, i64* %ptr_current_y
  %r62 = load i64, i64* @FB_PITCH
  %r63 = mul i64 %r61, %r62
  %r64 = load i64, i64* %ptr_start_x
  %r65 = mul i64 %r64, 4
  %r66 = add i64 %r63, %r65
  store i64 %r66, i64* %ptr_offset
  %r67 = load i64, i64* @BACK_BUFFER
  %r68 = load i64, i64* %ptr_offset
  %r69 = add i64 %r67, %r68
  store i64 %r69, i64* %ptr_row_addr
  %r70 = load i64, i64* %ptr_row_addr
  %r71 = load i64, i64* %ptr_color
  %r72 = load i64, i64* %ptr_draw_w
  %r73 = call i64 @fast_fill32(i64 %r70, i64 %r71, i64 %r72)
  %r74 = load i64, i64* %ptr_j
  %r75 = call i64 @_add(i64 %r74, i64 1)
  store i64 %r75, i64* %ptr_j
  br label %L71
L73:
  br label %L70
L70:
  ret i64 0
}
define i64 @draw_node(i64 %arg_x, i64 %arg_y, i64 %arg_w, i64 %arg_h, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_x = alloca i64
  store i64 %arg_x, i64* %ptr_x
  %ptr_y = alloca i64
  store i64 %arg_y, i64* %ptr_y
  %ptr_w = alloca i64
  store i64 %arg_w, i64* %ptr_w
  %ptr_h = alloca i64
  store i64 %arg_h, i64* %ptr_h
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_t = alloca i64
  %r1 = load i64, i64* %ptr_x
  %r2 = load i64, i64* %ptr_y
  %r3 = load i64, i64* %ptr_w
  %r4 = load i64, i64* %ptr_h
  %r5 = call i64 @draw_rect(i64 %r1, i64 %r2, i64 %r3, i64 %r4, i64 15, i64 15, i64 18)
  store i64 2, i64* %ptr_t
  %r6 = load i64, i64* %ptr_x
  %r7 = load i64, i64* %ptr_y
  %r8 = load i64, i64* %ptr_w
  %r9 = load i64, i64* %ptr_t
  %r10 = load i64, i64* %ptr_r
  %r11 = load i64, i64* %ptr_g
  %r12 = load i64, i64* %ptr_b
  %r13 = call i64 @draw_rect(i64 %r6, i64 %r7, i64 %r8, i64 %r9, i64 %r10, i64 %r11, i64 %r12)
  %r14 = load i64, i64* %ptr_x
  %r15 = load i64, i64* %ptr_y
  %r16 = load i64, i64* %ptr_h
  %r17 = call i64 @_add(i64 %r15, i64 %r16)
  %r18 = load i64, i64* %ptr_t
  %r19 = sub i64 %r17, %r18
  %r20 = load i64, i64* %ptr_w
  %r21 = load i64, i64* %ptr_t
  %r22 = load i64, i64* %ptr_r
  %r23 = load i64, i64* %ptr_g
  %r24 = load i64, i64* %ptr_b
  %r25 = call i64 @draw_rect(i64 %r14, i64 %r19, i64 %r20, i64 %r21, i64 %r22, i64 %r23, i64 %r24)
  %r26 = load i64, i64* %ptr_x
  %r27 = load i64, i64* %ptr_y
  %r28 = load i64, i64* %ptr_t
  %r29 = load i64, i64* %ptr_h
  %r30 = load i64, i64* %ptr_r
  %r31 = load i64, i64* %ptr_g
  %r32 = load i64, i64* %ptr_b
  %r33 = call i64 @draw_rect(i64 %r26, i64 %r27, i64 %r28, i64 %r29, i64 %r30, i64 %r31, i64 %r32)
  %r34 = load i64, i64* %ptr_x
  %r35 = load i64, i64* %ptr_w
  %r36 = call i64 @_add(i64 %r34, i64 %r35)
  %r37 = load i64, i64* %ptr_t
  %r38 = sub i64 %r36, %r37
  %r39 = load i64, i64* %ptr_y
  %r40 = load i64, i64* %ptr_t
  %r41 = load i64, i64* %ptr_h
  %r42 = load i64, i64* %ptr_r
  %r43 = load i64, i64* %ptr_g
  %r44 = load i64, i64* %ptr_b
  %r45 = call i64 @draw_rect(i64 %r38, i64 %r39, i64 %r40, i64 %r41, i64 %r42, i64 %r43, i64 %r44)
  ret i64 0
}
define i64 @draw_canvas_gradient() {
  %ptr_y = alloca i64
  %ptr_x = alloca i64
  %ptr_b_val = alloca i64
  %ptr_r_val = alloca i64
  store i64 0, i64* %ptr_y
  br label %L74
L74:
  %r1 = load i64, i64* %ptr_y
  %r2 = load i64, i64* @FB_HEIGHT
  %r4 = icmp slt i64 %r1, %r2
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L75, label %L76
L75:
  store i64 0, i64* %ptr_x
  %r6 = load i64, i64* %ptr_y
  %r7 = mul i64 %r6, 255
  %r8 = load i64, i64* @FB_HEIGHT
  %r9 = sdiv i64 %r7, %r8
  store i64 %r9, i64* %ptr_b_val
  br label %L77
L77:
  %r10 = load i64, i64* %ptr_x
  %r11 = load i64, i64* @FB_WIDTH
  %r13 = icmp slt i64 %r10, %r11
  %r12 = zext i1 %r13 to i64
  %r14 = icmp ne i64 %r12, 0
  br i1 %r14, label %L78, label %L79
L78:
  %r15 = load i64, i64* %ptr_x
  %r16 = mul i64 %r15, 255
  %r17 = load i64, i64* @FB_WIDTH
  %r18 = sdiv i64 %r16, %r17
  store i64 %r18, i64* %ptr_r_val
  %r19 = load i64, i64* %ptr_x
  %r20 = load i64, i64* %ptr_y
  %r21 = load i64, i64* %ptr_r_val
  %r22 = sdiv i64 %r21, 3
  %r23 = load i64, i64* %ptr_b_val
  %r24 = sdiv i64 %r23, 2
  %r25 = call i64 @put_pixel(i64 %r19, i64 %r20, i64 %r22, i64 5, i64 %r24)
  %r26 = load i64, i64* %ptr_x
  %r27 = call i64 @_add(i64 %r26, i64 1)
  store i64 %r27, i64* %ptr_x
  br label %L77
L79:
  %r28 = load i64, i64* %ptr_y
  %r29 = call i64 @_add(i64 %r28, i64 1)
  store i64 %r29, i64* %ptr_y
  br label %L74
L76:
  ret i64 0
}
define i64 @get_scancode() {
  %ptr_status = alloca i64
  %ptr_is_ready = alloca i64
  %r1 = trunc i64 100 to i16
  %r2 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r1)
  %r3 = zext i8 %r2 to i64
  store i64 %r3, i64* %ptr_status
  %r4 = load i64, i64* %ptr_status
  %r5 = and i64 %r4, 1
  store i64 %r5, i64* %ptr_is_ready
  %r6 = load i64, i64* %ptr_is_ready
  %r7 = icmp ne i64 %r6, 0
  br i1 %r7, label %L80, label %L82
L80:
  %r8 = trunc i64 96 to i16
  %r9 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r8)
  %r10 = zext i8 %r9 to i64
  ret i64 %r10
  br label %L82
L82:
  ret i64 0
  ret i64 0
}
define i64 @int_to_str(i64 %arg_n) {
  %ptr_n = alloca i64
  store i64 %arg_n, i64* %ptr_n
  %ptr_out = alloca i64
  %ptr_is_neg = alloca i64
  %ptr_digit = alloca i64
  %ptr_c = alloca i64
  %r1 = load i64, i64* %ptr_n
  %r2 = call i64 @_eq(i64 %r1, i64 0)
  %r3 = icmp ne i64 %r2, 0
  br i1 %r3, label %L83, label %L85
L83:
  %r4 = getelementptr [2 x i8], [2 x i8]* @.str.9, i64 0, i64 0
  %r5 = ptrtoint i8* %r4 to i64
  ret i64 %r5
  br label %L85
L85:
  %r6 = getelementptr [1 x i8], [1 x i8]* @.str.10, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  store i64 %r7, i64* %ptr_out
  store i64 0, i64* %ptr_is_neg
  %r8 = load i64, i64* %ptr_n
  %r10 = icmp slt i64 %r8, 0
  %r9 = zext i1 %r10 to i64
  %r11 = icmp ne i64 %r9, 0
  br i1 %r11, label %L86, label %L88
L86:
  store i64 1, i64* %ptr_is_neg
  %r12 = load i64, i64* %ptr_n
  %r13 = sub i64 0, %r12
  store i64 %r13, i64* %ptr_n
  br label %L88
L88:
  br label %L89
L89:
  %r14 = load i64, i64* %ptr_n
  %r16 = icmp sgt i64 %r14, 0
  %r15 = zext i1 %r16 to i64
  %r17 = icmp ne i64 %r15, 0
  br i1 %r17, label %L90, label %L91
L90:
  %r18 = load i64, i64* %ptr_n
  %r19 = srem i64 %r18, 10
  store i64 %r19, i64* %ptr_digit
  %r20 = load i64, i64* %ptr_digit
  %r21 = call i64 @_add(i64 48, i64 %r20)
  store i64 %r21, i64* %ptr_c
  %r22 = load i64, i64* %ptr_c
  %r23 = call i64 @signum_ex(i64 %r22)
  %r24 = load i64, i64* %ptr_out
  %r25 = call i64 @_add(i64 %r23, i64 %r24)
  store i64 %r25, i64* %ptr_out
  %r26 = load i64, i64* %ptr_n
  %r27 = sdiv i64 %r26, 10
  store i64 %r27, i64* %ptr_n
  br label %L89
L91:
  %r28 = load i64, i64* %ptr_is_neg
  %r29 = icmp ne i64 %r28, 0
  br i1 %r29, label %L92, label %L94
L92:
  %r30 = getelementptr [2 x i8], [2 x i8]* @.str.11, i64 0, i64 0
  %r31 = ptrtoint i8* %r30 to i64
  %r32 = load i64, i64* %ptr_out
  %r33 = call i64 @_add(i64 %r31, i64 %r32)
  store i64 %r33, i64* %ptr_out
  br label %L94
L94:
  %r34 = load i64, i64* %ptr_out
  ret i64 %r34
  ret i64 0
}
define i64 @get_char_from_code(i64 %arg_code) {
  %ptr_code = alloca i64
  store i64 %arg_code, i64* %ptr_code
  %r1 = load i64, i64* %ptr_code
  %r3 = icmp sge i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  store i64 0, i64* @.sc.12
  %r5 = icmp ne i64 %r2, 0
  br i1 %r5, label %L95, label %L96
L95:
  %r6 = load i64, i64* %ptr_code
  %r8 = icmp sle i64 %r6, 57
  %r7 = zext i1 %r8 to i64
  %r9 = icmp ne i64 %r7, 0
  %r10 = zext i1 %r9 to i64
  store i64 %r10, i64* @.sc.12
  br label %L96
L96:
  %r4 = load i64, i64* @.sc.12
  %r11 = icmp ne i64 %r4, 0
  br i1 %r11, label %L97, label %L99
L97:
  %r12 = load i64, i64* @kbd_map
  %r13 = load i64, i64* %ptr_code
  %r14 = call i64 @_get(i64 %r12, i64 %r13)
  ret i64 %r14
  br label %L99
L99:
  %r15 = getelementptr [1 x i8], [1 x i8]* @.str.13, i64 0, i64 0
  %r16 = ptrtoint i8* %r15 to i64
  ret i64 %r16
  ret i64 0
}
define i64 @init_font() {
  %ptr_i = alloca i64
  store i64 0, i64* %ptr_i
  br label %L100
L100:
  %r1 = load i64, i64* %ptr_i
  %r3 = icmp slt i64 %r1, 128
  %r2 = zext i1 %r3 to i64
  %r4 = icmp ne i64 %r2, 0
  br i1 %r4, label %L101, label %L102
L101:
  %r5 = load i64, i64* @FONT
  call i64 @_append_poly(i64 %r5, i64 0)
  %r6 = load i64, i64* %ptr_i
  %r7 = call i64 @_add(i64 %r6, i64 1)
  store i64 %r7, i64* %ptr_i
  br label %L100
L102:
  %r8 = load i64, i64* @FONT
  call i64 @_set(i64 %r8, i64 32, i64 0)
  %r9 = load i64, i64* @FONT
  call i64 @_set(i64 %r9, i64 33, i64 1736164147711180800)
  %r10 = load i64, i64* @FONT
  call i64 @_set(i64 %r10, i64 45, i64 541165879296)
  %r11 = load i64, i64* @FONT
  call i64 @_set(i64 %r11, i64 46, i64 1579008)
  %r12 = load i64, i64* @FONT
  call i64 @_set(i64 %r12, i64 47, i64 290499906672525312)
  %r13 = load i64, i64* @FONT
  call i64 @_set(i64 %r13, i64 58, i64 6781787721701376)
  %r14 = load i64, i64* @FONT
  call i64 @_set(i64 %r14, i64 62, i64 4620710844498460672)
  %r15 = load i64, i64* @FONT
  call i64 @_set(i64 %r15, i64 91, i64 4332498163880442880)
  %r16 = load i64, i64* @FONT
  call i64 @_set(i64 %r16, i64 93, i64 4324585957476285440)
  %r17 = load i64, i64* @FONT
  call i64 @_set(i64 %r17, i64 95, i64 65280)
  %r18 = load i64, i64* @FONT
  call i64 @_set(i64 %r18, i64 126, i64 216023433216)
  %r19 = load i64, i64* @FONT
  call i64 @_set(i64 %r19, i64 34, i64 2604224076713033728)
  %r20 = load i64, i64* @FONT
  call i64 @_set(i64 %r20, i64 35, i64 2604345179727209472)
  %r21 = load i64, i64* @FONT
  call i64 @_set(i64 %r21, i64 36, i64 593956447784404992)
  %r22 = load i64, i64* @FONT
  call i64 @_set(i64 %r22, i64 37, i64 7089800578842624000)
  %r23 = load i64, i64* @FONT
  call i64 @_set(i64 %r23, i64 38, i64 4054427499180064768)
  %r24 = load i64, i64* @FONT
  call i64 @_set(i64 %r24, i64 39, i64 1736146452444348416)
  %r25 = load i64, i64* @FONT
  call i64 @_set(i64 %r25, i64 40, i64 580999674279757824)
  %r26 = load i64, i64* @FONT
  call i64 @_set(i64 %r26, i64 41, i64 2310355439429099520)
  %r27 = load i64, i64* @FONT
  call i64 @_set(i64 %r27, i64 42, i64 5638562050736128)
  %r28 = load i64, i64* @FONT
  call i64 @_set(i64 %r28, i64 43, i64 2260862329421824)
  %r29 = load i64, i64* @FONT
  call i64 @_set(i64 %r29, i64 44, i64 1576992)
  %r30 = load i64, i64* @FONT
  call i64 @_set(i64 %r30, i64 59, i64 6781788123303936)
  %r31 = load i64, i64* @FONT
  call i64 @_set(i64 %r31, i64 60, i64 580999811718711296)
  %r32 = load i64, i64* @FONT
  call i64 @_set(i64 %r32, i64 61, i64 68170761109504)
  %r33 = load i64, i64* @FONT
  call i64 @_set(i64 %r33, i64 63, i64 4342037423413268480)
  %r34 = load i64, i64* @FONT
  call i64 @_set(i64 %r34, i64 64, i64 4342132334443364352)
  %r35 = load i64, i64* @FONT
  call i64 @_set(i64 %r35, i64 92, i64 4620710844295151872)
  %r36 = load i64, i64* @FONT
  call i64 @_set(i64 %r36, i64 94, i64 582127635232980992)
  %r37 = load i64, i64* @FONT
  call i64 @_set(i64 %r37, i64 96, i64 1161928703861587968)
  %r38 = load i64, i64* @FONT
  call i64 @_set(i64 %r38, i64 123, i64 869212457976990720)
  %r39 = load i64, i64* @FONT
  call i64 @_set(i64 %r39, i64 124, i64 578721382704613376)
  %r40 = load i64, i64* @FONT
  call i64 @_set(i64 %r40, i64 125, i64 3461025127041871872)
  %r41 = load i64, i64* @FONT
  call i64 @_set(i64 %r41, i64 48, i64 4342105843085491200)
  %r42 = load i64, i64* @FONT
  call i64 @_set(i64 %r42, i64 49, i64 583260166704086528)
  %r43 = load i64, i64* @FONT
  call i64 @_set(i64 %r43, i64 50, i64 4342037423415393792)
  %r44 = load i64, i64* @FONT
  call i64 @_set(i64 %r44, i64 51, i64 4342037491935755264)
  %r45 = load i64, i64* @FONT
  call i64 @_set(i64 %r45, i64 52, i64 583260443561691136)
  %r46 = load i64, i64* @FONT
  call i64 @_set(i64 %r46, i64 53, i64 9097407595358075904)
  %r47 = load i64, i64* @FONT
  call i64 @_set(i64 %r47, i64 54, i64 4341606664806480896)
  %r48 = load i64, i64* @FONT
  call i64 @_set(i64 %r48, i64 55, i64 9079824231409139712)
  %r49 = load i64, i64* @FONT
  call i64 @_set(i64 %r49, i64 56, i64 4342105817315687424)
  %r50 = load i64, i64* @FONT
  call i64 @_set(i64 %r50, i64 57, i64 4342105824831880192)
  %r51 = load i64, i64* @FONT
  call i64 @_set(i64 %r51, i64 65, i64 4054440865052247040)
  %r52 = load i64, i64* @FONT
  call i64 @_set(i64 %r52, i64 66, i64 8657084207256074240)
  %r53 = load i64, i64* @FONT
  call i64 @_set(i64 %r53, i64 67, i64 4054436209240586240)
  %r54 = load i64, i64* @FONT
  call i64 @_set(i64 %r54, i64 68, i64 8657084121356728320)
  %r55 = load i64, i64* @FONT
  call i64 @_set(i64 %r55, i64 69, i64 8953226944430767104)
  %r56 = load i64, i64* @FONT
  call i64 @_set(i64 %r56, i64 70, i64 8953226944430751744)
  %r57 = load i64, i64* @FONT
  call i64 @_set(i64 %r57, i64 71, i64 4054436260847302656)
  %r58 = load i64, i64* @FONT
  call i64 @_set(i64 %r58, i64 72, i64 4919131993507382272)
  %r59 = load i64, i64* @FONT
  call i64 @_set(i64 %r59, i64 73, i64 4039746526926354432)
  %r60 = load i64, i64* @FONT
  call i64 @_set(i64 %r60, i64 74, i64 865821443659937792)
  %r61 = load i64, i64* @FONT
  call i64 @_set(i64 %r61, i64 75, i64 4920270967496262656)
  %r62 = load i64, i64* @FONT
  call i64 @_set(i64 %r62, i64 76, i64 4629771061636922368)
  %r63 = load i64, i64* @FONT
  call i64 @_set(i64 %r63, i64 77, i64 4930408412963161088)
  %r64 = load i64, i64* @FONT
  call i64 @_set(i64 %r64, i64 78, i64 4928156578789737472)
  %r65 = load i64, i64* @FONT
  call i64 @_set(i64 %r65, i64 79, i64 4054440624534075392)
  %r66 = load i64, i64* @FONT
  call i64 @_set(i64 %r66, i64 80, i64 8666126866232393728)
  %r67 = load i64, i64* @FONT
  call i64 @_set(i64 %r67, i64 81, i64 4054440624802771968)
  %r68 = load i64, i64* @FONT
  call i64 @_set(i64 %r68, i64 82, i64 8666126866501354496)
  %r69 = load i64, i64* @FONT
  call i64 @_set(i64 %r69, i64 83, i64 4054436173874214912)
  %r70 = load i64, i64* @FONT
  call i64 @_set(i64 %r70, i64 84, i64 8939662921505443840)
  %r71 = load i64, i64* @FONT
  call i64 @_set(i64 %r71, i64 85, i64 4919131752989210624)
  %r72 = load i64, i64* @FONT
  call i64 @_set(i64 %r72, i64 86, i64 4919131752987365376)
  %r73 = load i64, i64* @FONT
  call i64 @_set(i64 %r73, i64 87, i64 4919131821979747328)
  %r74 = load i64, i64* @FONT
  call i64 @_set(i64 %r74, i64 88, i64 4919100742855574528)
  %r75 = load i64, i64* @FONT
  call i64 @_set(i64 %r75, i64 89, i64 4919100742449500160)
  %r76 = load i64, i64* @FONT
  call i64 @_set(i64 %r76, i64 90, i64 8936276425963502592)
  %r77 = load i64, i64* @FONT
  call i64 @_set(i64 %r77, i64 97, i64 65988888640512)
  %r78 = load i64, i64* @FONT
  call i64 @_set(i64 %r78, i64 98, i64 4629837040958209024)
  %r79 = load i64, i64* @FONT
  call i64 @_set(i64 %r79, i64 99, i64 66246653524992)
  %r80 = load i64, i64* @FONT
  call i64 @_set(i64 %r80, i64 100, i64 289424738982575616)
  %r81 = load i64, i64* @FONT
  call i64 @_set(i64 %r81, i64 101, i64 66264840027136)
  %r82 = load i64, i64* @FONT
  call i64 @_set(i64 %r82, i64 102, i64 1739551022019256320)
  %r83 = load i64, i64* @FONT
  call i64 @_set(i64 %r83, i64 103, i64 17526508444989440)
  %r84 = load i64, i64* @FONT
  call i64 @_set(i64 %r84, i64 104, i64 4629837040958194176)
  %r85 = load i64, i64* @FONT
  call i64 @_set(i64 %r85, i64 105, i64 1152974350153955328)
  %r86 = load i64, i64* @FONT
  call i64 @_set(i64 %r86, i64 106, i64 576487175076988976)
  %r87 = load i64, i64* @FONT
  call i64 @_set(i64 %r87, i64 107, i64 2314889963493663744)
  %r88 = load i64, i64* @FONT
  call i64 @_set(i64 %r88, i64 108, i64 3463285774622930944)
  %r89 = load i64, i64* @FONT
  call i64 @_set(i64 %r89, i64 109, i64 119109447865344)
  %r90 = load i64, i64* @FONT
  call i64 @_set(i64 %r90, i64 110, i64 136624021324288)
  %r91 = load i64, i64* @FONT
  call i64 @_set(i64 %r91, i64 111, i64 66255277145088)
  %r92 = load i64, i64* @FONT
  call i64 @_set(i64 %r92, i64 112, i64 132234601840704)
  %r93 = load i64, i64* @FONT
  call i64 @_set(i64 %r93, i64 113, i64 68454300123650)
  %r94 = load i64, i64* @FONT
  call i64 @_set(i64 %r94, i64 114, i64 101577054502912)
  %r95 = load i64, i64* @FONT
  call i64 @_set(i64 %r95, i64 115, i64 68445605624832)
  %r96 = load i64, i64* @FONT
  call i64 @_set(i64 %r96, i64 116, i64 2314973491748673536)
  %r97 = load i64, i64* @FONT
  call i64 @_set(i64 %r97, i64 117, i64 72852346912256)
  %r98 = load i64, i64* @FONT
  call i64 @_set(i64 %r98, i64 118, i64 72852344936448)
  %r99 = load i64, i64* @FONT
  call i64 @_set(i64 %r99, i64 119, i64 72852751131648)
  %r100 = load i64, i64* @FONT
  call i64 @_set(i64 %r100, i64 120, i64 72722791285248)
  %r101 = load i64, i64* @FONT
  call i64 @_set(i64 %r101, i64 121, i64 72722789437536)
  %r102 = load i64, i64* @FONT
  call i64 @_set(i64 %r102, i64 122, i64 138573095403008)
  ret i64 0
}
define i64 @draw_char(i64 %arg_x, i64 %arg_y, i64 %arg_ascii_code, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_x = alloca i64
  store i64 %arg_x, i64* %ptr_x
  %ptr_y = alloca i64
  store i64 %arg_y, i64* %ptr_y
  %ptr_ascii_code = alloca i64
  store i64 %arg_ascii_code, i64* %ptr_ascii_code
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_font_val = alloca i64
  %ptr_row = alloca i64
  %ptr_col = alloca i64
  %ptr_row_data = alloca i64
  %ptr_bit = alloca i64
  %r1 = load i64, i64* %ptr_ascii_code
  %r3 = icmp sge i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  store i64 0, i64* @.sc.14
  %r5 = icmp ne i64 %r2, 0
  br i1 %r5, label %L103, label %L104
L103:
  %r6 = load i64, i64* %ptr_ascii_code
  %r8 = icmp slt i64 %r6, 128
  %r7 = zext i1 %r8 to i64
  %r9 = icmp ne i64 %r7, 0
  %r10 = zext i1 %r9 to i64
  store i64 %r10, i64* @.sc.14
  br label %L104
L104:
  %r4 = load i64, i64* @.sc.14
  %r11 = icmp ne i64 %r4, 0
  br i1 %r11, label %L105, label %L107
L105:
  %r12 = load i64, i64* @FONT
  %r13 = load i64, i64* %ptr_ascii_code
  %r14 = call i64 @_get(i64 %r12, i64 %r13)
  store i64 %r14, i64* %ptr_font_val
  store i64 0, i64* %ptr_row
  br label %L108
L108:
  %r15 = load i64, i64* %ptr_row
  %r17 = icmp slt i64 %r15, 8
  %r16 = zext i1 %r17 to i64
  %r18 = icmp ne i64 %r16, 0
  br i1 %r18, label %L109, label %L110
L109:
  store i64 0, i64* %ptr_col
  %r19 = load i64, i64* %ptr_font_val
  %r20 = load i64, i64* %ptr_row
  %r21 = sub i64 7, %r20
  %r22 = mul i64 %r21, 8
  %r23 = lshr i64 %r19, %r22
  %r24 = and i64 %r23, 255
  store i64 %r24, i64* %ptr_row_data
  br label %L111
L111:
  %r25 = load i64, i64* %ptr_col
  %r27 = icmp slt i64 %r25, 8
  %r26 = zext i1 %r27 to i64
  %r28 = icmp ne i64 %r26, 0
  br i1 %r28, label %L112, label %L113
L112:
  %r29 = load i64, i64* %ptr_row_data
  %r30 = load i64, i64* %ptr_col
  %r31 = sub i64 7, %r30
  %r32 = lshr i64 %r29, %r31
  %r33 = and i64 %r32, 1
  store i64 %r33, i64* %ptr_bit
  %r34 = load i64, i64* %ptr_bit
  %r35 = call i64 @_eq(i64 %r34, i64 1)
  %r36 = icmp ne i64 %r35, 0
  br i1 %r36, label %L114, label %L116
L114:
  %r37 = load i64, i64* %ptr_x
  %r38 = load i64, i64* %ptr_col
  %r39 = call i64 @_add(i64 %r37, i64 %r38)
  %r40 = load i64, i64* %ptr_y
  %r41 = load i64, i64* %ptr_row
  %r42 = call i64 @_add(i64 %r40, i64 %r41)
  %r43 = load i64, i64* %ptr_r
  %r44 = load i64, i64* %ptr_g
  %r45 = load i64, i64* %ptr_b
  %r46 = call i64 @put_pixel(i64 %r39, i64 %r42, i64 %r43, i64 %r44, i64 %r45)
  br label %L116
L116:
  %r47 = load i64, i64* %ptr_col
  %r48 = call i64 @_add(i64 %r47, i64 1)
  store i64 %r48, i64* %ptr_col
  br label %L111
L113:
  %r49 = load i64, i64* %ptr_row
  %r50 = call i64 @_add(i64 %r49, i64 1)
  store i64 %r50, i64* %ptr_row
  br label %L108
L110:
  br label %L107
L107:
  ret i64 0
}
define i64 @world_to_screen_x(i64 %arg_wx) {
  %ptr_wx = alloca i64
  store i64 %arg_wx, i64* %ptr_wx
  %r1 = load i64, i64* %ptr_wx
  %r2 = load i64, i64* @cam_x
  %r3 = sub i64 %r1, %r2
  %r4 = load i64, i64* @cam_z
  %r5 = mul i64 %r3, %r4
  %r6 = sdiv i64 %r5, 100
  %r7 = load i64, i64* @FB_WIDTH
  %r8 = sdiv i64 %r7, 2
  %r9 = call i64 @_add(i64 %r6, i64 %r8)
  ret i64 %r9
  ret i64 0
}
define i64 @world_to_screen_y(i64 %arg_wy) {
  %ptr_wy = alloca i64
  store i64 %arg_wy, i64* %ptr_wy
  %r1 = load i64, i64* %ptr_wy
  %r2 = load i64, i64* @cam_y
  %r3 = sub i64 %r1, %r2
  %r4 = load i64, i64* @cam_z
  %r5 = mul i64 %r3, %r4
  %r6 = sdiv i64 %r5, 100
  %r7 = load i64, i64* @FB_HEIGHT
  %r8 = sdiv i64 %r7, 2
  %r9 = call i64 @_add(i64 %r6, i64 %r8)
  ret i64 %r9
  ret i64 0
}
define i64 @scale_size(i64 %arg_s) {
  %ptr_s = alloca i64
  store i64 %arg_s, i64* %ptr_s
  %r1 = load i64, i64* %ptr_s
  %r2 = load i64, i64* @cam_z
  %r3 = mul i64 %r1, %r2
  %r4 = sdiv i64 %r3, 100
  ret i64 %r4
  ret i64 0
}
define i64 @screen_to_world_x(i64 %arg_sx) {
  %ptr_sx = alloca i64
  store i64 %arg_sx, i64* %ptr_sx
  %r1 = load i64, i64* %ptr_sx
  %r2 = load i64, i64* @FB_WIDTH
  %r3 = sdiv i64 %r2, 2
  %r4 = sub i64 %r1, %r3
  %r5 = mul i64 %r4, 100
  %r6 = load i64, i64* @cam_z
  %r7 = sdiv i64 %r5, %r6
  %r8 = load i64, i64* @cam_x
  %r9 = call i64 @_add(i64 %r7, i64 %r8)
  ret i64 %r9
  ret i64 0
}
define i64 @screen_to_world_y(i64 %arg_sy) {
  %ptr_sy = alloca i64
  store i64 %arg_sy, i64* %ptr_sy
  %r1 = load i64, i64* %ptr_sy
  %r2 = load i64, i64* @FB_HEIGHT
  %r3 = sdiv i64 %r2, 2
  %r4 = sub i64 %r1, %r3
  %r5 = mul i64 %r4, 100
  %r6 = load i64, i64* @cam_z
  %r7 = sdiv i64 %r5, %r6
  %r8 = load i64, i64* @cam_y
  %r9 = call i64 @_add(i64 %r7, i64 %r8)
  ret i64 %r9
  ret i64 0
}
define i64 @draw_zui_node(i64 %arg_wx, i64 %arg_wy, i64 %arg_ww, i64 %arg_wh, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_wx = alloca i64
  store i64 %arg_wx, i64* %ptr_wx
  %ptr_wy = alloca i64
  store i64 %arg_wy, i64* %ptr_wy
  %ptr_ww = alloca i64
  store i64 %arg_ww, i64* %ptr_ww
  %ptr_wh = alloca i64
  store i64 %arg_wh, i64* %ptr_wh
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_sx = alloca i64
  %ptr_sy = alloca i64
  %ptr_sw = alloca i64
  %ptr_sh = alloca i64
  %r1 = load i64, i64* %ptr_wx
  %r2 = call i64 @world_to_screen_x(i64 %r1)
  store i64 %r2, i64* %ptr_sx
  %r3 = load i64, i64* %ptr_wy
  %r4 = call i64 @world_to_screen_y(i64 %r3)
  store i64 %r4, i64* %ptr_sy
  %r5 = load i64, i64* %ptr_ww
  %r6 = call i64 @scale_size(i64 %r5)
  store i64 %r6, i64* %ptr_sw
  %r7 = load i64, i64* %ptr_wh
  %r8 = call i64 @scale_size(i64 %r7)
  store i64 %r8, i64* %ptr_sh
  %r9 = load i64, i64* %ptr_sx
  %r10 = load i64, i64* %ptr_sw
  %r11 = call i64 @_add(i64 %r9, i64 %r10)
  %r13 = icmp sgt i64 %r11, 0
  %r12 = zext i1 %r13 to i64
  store i64 0, i64* @.sc.17
  %r15 = icmp ne i64 %r12, 0
  br i1 %r15, label %L117, label %L118
L117:
  %r16 = load i64, i64* %ptr_sx
  %r17 = load i64, i64* @FB_WIDTH
  %r19 = icmp slt i64 %r16, %r17
  %r18 = zext i1 %r19 to i64
  %r20 = icmp ne i64 %r18, 0
  %r21 = zext i1 %r20 to i64
  store i64 %r21, i64* @.sc.17
  br label %L118
L118:
  %r14 = load i64, i64* @.sc.17
  store i64 0, i64* @.sc.16
  %r23 = icmp ne i64 %r14, 0
  br i1 %r23, label %L119, label %L120
L119:
  %r24 = load i64, i64* %ptr_sy
  %r25 = load i64, i64* %ptr_sh
  %r26 = call i64 @_add(i64 %r24, i64 %r25)
  %r28 = icmp sgt i64 %r26, 0
  %r27 = zext i1 %r28 to i64
  %r29 = icmp ne i64 %r27, 0
  %r30 = zext i1 %r29 to i64
  store i64 %r30, i64* @.sc.16
  br label %L120
L120:
  %r22 = load i64, i64* @.sc.16
  store i64 0, i64* @.sc.15
  %r32 = icmp ne i64 %r22, 0
  br i1 %r32, label %L121, label %L122
L121:
  %r33 = load i64, i64* %ptr_sy
  %r34 = load i64, i64* @FB_HEIGHT
  %r36 = icmp slt i64 %r33, %r34
  %r35 = zext i1 %r36 to i64
  %r37 = icmp ne i64 %r35, 0
  %r38 = zext i1 %r37 to i64
  store i64 %r38, i64* @.sc.15
  br label %L122
L122:
  %r31 = load i64, i64* @.sc.15
  %r39 = icmp ne i64 %r31, 0
  br i1 %r39, label %L123, label %L125
L123:
  %r40 = load i64, i64* %ptr_sx
  %r41 = load i64, i64* %ptr_sy
  %r42 = load i64, i64* %ptr_sw
  %r43 = load i64, i64* %ptr_sh
  %r44 = load i64, i64* %ptr_r
  %r45 = load i64, i64* %ptr_g
  %r46 = load i64, i64* %ptr_b
  %r47 = call i64 @draw_node(i64 %r40, i64 %r41, i64 %r42, i64 %r43, i64 %r44, i64 %r45, i64 %r46)
  br label %L125
L125:
  ret i64 0
}
define i64 @mouse_wait(i64 %arg_type) {
  %ptr_type = alloca i64
  store i64 %arg_type, i64* %ptr_type
  %ptr_time_out = alloca i64
  %ptr_stat = alloca i64
  store i64 100000, i64* %ptr_time_out
  br label %L126
L126:
  %r1 = load i64, i64* %ptr_time_out
  %r3 = icmp sgt i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  %r4 = icmp ne i64 %r2, 0
  br i1 %r4, label %L127, label %L128
L127:
  %r5 = trunc i64 100 to i16
  %r6 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r5)
  %r7 = zext i8 %r6 to i64
  store i64 %r7, i64* %ptr_stat
  %r8 = load i64, i64* %ptr_type
  %r9 = call i64 @_eq(i64 %r8, i64 0)
  %r10 = icmp ne i64 %r9, 0
  br i1 %r10, label %L129, label %L131
L129:
  %r11 = load i64, i64* %ptr_stat
  %r12 = and i64 %r11, 1
  %r13 = call i64 @_eq(i64 %r12, i64 1)
  %r14 = icmp ne i64 %r13, 0
  br i1 %r14, label %L132, label %L134
L132:
  ret i64 1
  br label %L134
L134:
  br label %L131
L131:
  %r15 = load i64, i64* %ptr_type
  %r16 = call i64 @_eq(i64 %r15, i64 1)
  %r17 = icmp ne i64 %r16, 0
  br i1 %r17, label %L135, label %L137
L135:
  %r18 = load i64, i64* %ptr_stat
  %r19 = and i64 %r18, 2
  %r20 = call i64 @_eq(i64 %r19, i64 0)
  %r21 = icmp ne i64 %r20, 0
  br i1 %r21, label %L138, label %L140
L138:
  ret i64 1
  br label %L140
L140:
  br label %L137
L137:
  %r22 = load i64, i64* %ptr_time_out
  %r23 = sub i64 %r22, 1
  store i64 %r23, i64* %ptr_time_out
  br label %L126
L128:
  ret i64 0
  ret i64 0
}
define i64 @mouse_write(i64 %arg_data) {
  %ptr_data = alloca i64
  store i64 %arg_data, i64* %ptr_data
  %r1 = call i64 @mouse_wait(i64 1)
  %r2 = trunc i64 100 to i16
  %r3 = trunc i64 212 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r3, i16 %r2)
  %r4 = call i64 @mouse_wait(i64 1)
  %r5 = load i64, i64* %ptr_data
  %r6 = trunc i64 96 to i16
  %r7 = trunc i64 %r5 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r7, i16 %r6)
  ret i64 0
}
define i64 @mouse_read() {
  %r1 = call i64 @mouse_wait(i64 0)
  %r2 = trunc i64 96 to i16
  %r3 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r2)
  %r4 = zext i8 %r3 to i64
  ret i64 %r4
  ret i64 0
}
define i64 @init_mouse() {
  %ptr_status = alloca i64
  %r1 = call i64 @mouse_wait(i64 1)
  %r2 = trunc i64 100 to i16
  %r3 = trunc i64 168 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r3, i16 %r2)
  %r4 = call i64 @mouse_wait(i64 1)
  %r5 = trunc i64 100 to i16
  %r6 = trunc i64 32 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r6, i16 %r5)
  %r7 = call i64 @mouse_wait(i64 0)
  %r8 = trunc i64 96 to i16
  %r9 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r8)
  %r10 = zext i8 %r9 to i64
  %r11 = or i64 %r10, 2
  store i64 %r11, i64* %ptr_status
  %r12 = call i64 @mouse_wait(i64 1)
  %r13 = trunc i64 100 to i16
  %r14 = trunc i64 96 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r14, i16 %r13)
  %r15 = call i64 @mouse_wait(i64 1)
  %r16 = load i64, i64* %ptr_status
  %r17 = trunc i64 96 to i16
  %r18 = trunc i64 %r16 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r18, i16 %r17)
  %r19 = call i64 @mouse_write(i64 246)
  %r20 = call i64 @mouse_read()
  %r21 = call i64 @mouse_write(i64 244)
  %r22 = call i64 @mouse_read()
  ret i64 0
}
define i64 @draw_reticle() {
  %r1 = load i64, i64* @mouse_x
  %r2 = sub i64 %r1, 10
  %r3 = load i64, i64* @mouse_y
  %r4 = sub i64 %r3, 1
  %r5 = call i64 @draw_rect(i64 %r2, i64 %r4, i64 8, i64 3, i64 0, i64 255, i64 150)
  %r6 = load i64, i64* @mouse_x
  %r7 = call i64 @_add(i64 %r6, i64 3)
  %r8 = load i64, i64* @mouse_y
  %r9 = sub i64 %r8, 1
  %r10 = call i64 @draw_rect(i64 %r7, i64 %r9, i64 8, i64 3, i64 0, i64 255, i64 150)
  %r11 = load i64, i64* @mouse_x
  %r12 = sub i64 %r11, 1
  %r13 = load i64, i64* @mouse_y
  %r14 = sub i64 %r13, 10
  %r15 = call i64 @draw_rect(i64 %r12, i64 %r14, i64 3, i64 8, i64 0, i64 255, i64 150)
  %r16 = load i64, i64* @mouse_x
  %r17 = sub i64 %r16, 1
  %r18 = load i64, i64* @mouse_y
  %r19 = call i64 @_add(i64 %r18, i64 3)
  %r20 = call i64 @draw_rect(i64 %r17, i64 %r19, i64 3, i64 8, i64 0, i64 255, i64 150)
  %r21 = load i64, i64* @mouse_l_down
  %r22 = icmp ne i64 %r21, 0
  br i1 %r22, label %L141, label %L142
L141:
  %r23 = load i64, i64* @mouse_x
  %r24 = load i64, i64* @mouse_y
  %r25 = call i64 @put_pixel(i64 %r23, i64 %r24, i64 255, i64 0, i64 150)
  br label %L143
L142:
  %r26 = load i64, i64* @mouse_x
  %r27 = load i64, i64* @mouse_y
  %r28 = call i64 @put_pixel(i64 %r26, i64 %r27, i64 0, i64 255, i64 255)
  br label %L143
L143:
  ret i64 0
}
define i64 @draw_zui_char(i64 %arg_wx, i64 %arg_wy, i64 %arg_size_mult, i64 %arg_ascii_code, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_wx = alloca i64
  store i64 %arg_wx, i64* %ptr_wx
  %ptr_wy = alloca i64
  store i64 %arg_wy, i64* %ptr_wy
  %ptr_size_mult = alloca i64
  store i64 %arg_size_mult, i64* %ptr_size_mult
  %ptr_ascii_code = alloca i64
  store i64 %arg_ascii_code, i64* %ptr_ascii_code
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_screen_w = alloca i64
  %ptr_sx = alloca i64
  %ptr_sy = alloca i64
  %ptr_font_val = alloca i64
  %ptr_row = alloca i64
  %ptr_col = alloca i64
  %ptr_row_data = alloca i64
  %ptr_bit = alloca i64
  %ptr_cell_wx = alloca i64
  %ptr_cell_wy = alloca i64
  %ptr_sw = alloca i64
  %r1 = load i64, i64* %ptr_size_mult
  %r2 = mul i64 8, %r1
  %r3 = call i64 @scale_size(i64 %r2)
  store i64 %r3, i64* %ptr_screen_w
  %r4 = load i64, i64* %ptr_screen_w
  %r6 = icmp slt i64 %r4, 4
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L144, label %L146
L144:
  %r8 = load i64, i64* %ptr_wx
  %r9 = call i64 @world_to_screen_x(i64 %r8)
  store i64 %r9, i64* %ptr_sx
  %r10 = load i64, i64* %ptr_wy
  %r11 = call i64 @world_to_screen_y(i64 %r10)
  store i64 %r11, i64* %ptr_sy
  %r12 = load i64, i64* %ptr_sx
  %r14 = icmp sge i64 %r12, 0
  %r13 = zext i1 %r14 to i64
  store i64 0, i64* @.sc.20
  %r16 = icmp ne i64 %r13, 0
  br i1 %r16, label %L147, label %L148
L147:
  %r17 = load i64, i64* %ptr_sx
  %r18 = load i64, i64* @FB_WIDTH
  %r20 = icmp slt i64 %r17, %r18
  %r19 = zext i1 %r20 to i64
  %r21 = icmp ne i64 %r19, 0
  %r22 = zext i1 %r21 to i64
  store i64 %r22, i64* @.sc.20
  br label %L148
L148:
  %r15 = load i64, i64* @.sc.20
  store i64 0, i64* @.sc.19
  %r24 = icmp ne i64 %r15, 0
  br i1 %r24, label %L149, label %L150
L149:
  %r25 = load i64, i64* %ptr_sy
  %r27 = icmp sge i64 %r25, 0
  %r26 = zext i1 %r27 to i64
  %r28 = icmp ne i64 %r26, 0
  %r29 = zext i1 %r28 to i64
  store i64 %r29, i64* @.sc.19
  br label %L150
L150:
  %r23 = load i64, i64* @.sc.19
  store i64 0, i64* @.sc.18
  %r31 = icmp ne i64 %r23, 0
  br i1 %r31, label %L151, label %L152
L151:
  %r32 = load i64, i64* %ptr_sy
  %r33 = load i64, i64* @FB_HEIGHT
  %r35 = icmp slt i64 %r32, %r33
  %r34 = zext i1 %r35 to i64
  %r36 = icmp ne i64 %r34, 0
  %r37 = zext i1 %r36 to i64
  store i64 %r37, i64* @.sc.18
  br label %L152
L152:
  %r30 = load i64, i64* @.sc.18
  %r38 = icmp ne i64 %r30, 0
  br i1 %r38, label %L153, label %L155
L153:
  %r39 = load i64, i64* %ptr_sx
  %r40 = load i64, i64* %ptr_sy
  %r41 = load i64, i64* %ptr_screen_w
  %r42 = load i64, i64* %ptr_size_mult
  %r43 = mul i64 8, %r42
  %r44 = call i64 @scale_size(i64 %r43)
  %r45 = load i64, i64* %ptr_r
  %r46 = sdiv i64 %r45, 2
  %r47 = load i64, i64* %ptr_g
  %r48 = sdiv i64 %r47, 2
  %r49 = load i64, i64* %ptr_b
  %r50 = sdiv i64 %r49, 2
  %r51 = call i64 @draw_rect(i64 %r39, i64 %r40, i64 %r41, i64 %r44, i64 %r46, i64 %r48, i64 %r50)
  br label %L155
L155:
  ret i64 0
  br label %L146
L146:
  %r52 = load i64, i64* %ptr_ascii_code
  %r54 = icmp sge i64 %r52, 0
  %r53 = zext i1 %r54 to i64
  store i64 0, i64* @.sc.21
  %r56 = icmp ne i64 %r53, 0
  br i1 %r56, label %L156, label %L157
L156:
  %r57 = load i64, i64* %ptr_ascii_code
  %r59 = icmp slt i64 %r57, 128
  %r58 = zext i1 %r59 to i64
  %r60 = icmp ne i64 %r58, 0
  %r61 = zext i1 %r60 to i64
  store i64 %r61, i64* @.sc.21
  br label %L157
L157:
  %r55 = load i64, i64* @.sc.21
  %r62 = icmp ne i64 %r55, 0
  br i1 %r62, label %L158, label %L160
L158:
  %r63 = load i64, i64* @FONT
  %r64 = load i64, i64* %ptr_ascii_code
  %r65 = call i64 @_get(i64 %r63, i64 %r64)
  store i64 %r65, i64* %ptr_font_val
  store i64 0, i64* %ptr_row
  br label %L161
L161:
  %r66 = load i64, i64* %ptr_row
  %r68 = icmp slt i64 %r66, 8
  %r67 = zext i1 %r68 to i64
  %r69 = icmp ne i64 %r67, 0
  br i1 %r69, label %L162, label %L163
L162:
  store i64 0, i64* %ptr_col
  %r70 = load i64, i64* %ptr_font_val
  %r71 = load i64, i64* %ptr_row
  %r72 = sub i64 7, %r71
  %r73 = mul i64 %r72, 8
  %r74 = lshr i64 %r70, %r73
  %r75 = and i64 %r74, 255
  store i64 %r75, i64* %ptr_row_data
  br label %L164
L164:
  %r76 = load i64, i64* %ptr_col
  %r78 = icmp slt i64 %r76, 8
  %r77 = zext i1 %r78 to i64
  %r79 = icmp ne i64 %r77, 0
  br i1 %r79, label %L165, label %L166
L165:
  %r80 = load i64, i64* %ptr_row_data
  %r81 = load i64, i64* %ptr_col
  %r82 = sub i64 7, %r81
  %r83 = lshr i64 %r80, %r82
  %r84 = and i64 %r83, 1
  store i64 %r84, i64* %ptr_bit
  %r85 = load i64, i64* %ptr_bit
  %r86 = call i64 @_eq(i64 %r85, i64 1)
  %r87 = icmp ne i64 %r86, 0
  br i1 %r87, label %L167, label %L169
L167:
  %r88 = load i64, i64* %ptr_wx
  %r89 = load i64, i64* %ptr_col
  %r90 = load i64, i64* %ptr_size_mult
  %r91 = mul i64 %r89, %r90
  %r92 = call i64 @_add(i64 %r88, i64 %r91)
  store i64 %r92, i64* %ptr_cell_wx
  %r93 = load i64, i64* %ptr_wy
  %r94 = load i64, i64* %ptr_row
  %r95 = load i64, i64* %ptr_size_mult
  %r96 = mul i64 %r94, %r95
  %r97 = call i64 @_add(i64 %r93, i64 %r96)
  store i64 %r97, i64* %ptr_cell_wy
  %r98 = load i64, i64* %ptr_cell_wx
  %r99 = call i64 @world_to_screen_x(i64 %r98)
  store i64 %r99, i64* %ptr_sx
  %r100 = load i64, i64* %ptr_cell_wy
  %r101 = call i64 @world_to_screen_y(i64 %r100)
  store i64 %r101, i64* %ptr_sy
  %r102 = load i64, i64* %ptr_size_mult
  %r103 = call i64 @scale_size(i64 %r102)
  store i64 %r103, i64* %ptr_sw
  %r104 = load i64, i64* %ptr_sw
  %r106 = icmp slt i64 %r104, 1
  %r105 = zext i1 %r106 to i64
  %r107 = icmp ne i64 %r105, 0
  br i1 %r107, label %L170, label %L172
L170:
  store i64 1, i64* %ptr_sw
  br label %L172
L172:
  %r108 = load i64, i64* %ptr_sx
  %r110 = icmp sge i64 %r108, 0
  %r109 = zext i1 %r110 to i64
  store i64 0, i64* @.sc.24
  %r112 = icmp ne i64 %r109, 0
  br i1 %r112, label %L173, label %L174
L173:
  %r113 = load i64, i64* %ptr_sx
  %r114 = load i64, i64* @FB_WIDTH
  %r116 = icmp slt i64 %r113, %r114
  %r115 = zext i1 %r116 to i64
  %r117 = icmp ne i64 %r115, 0
  %r118 = zext i1 %r117 to i64
  store i64 %r118, i64* @.sc.24
  br label %L174
L174:
  %r111 = load i64, i64* @.sc.24
  store i64 0, i64* @.sc.23
  %r120 = icmp ne i64 %r111, 0
  br i1 %r120, label %L175, label %L176
L175:
  %r121 = load i64, i64* %ptr_sy
  %r123 = icmp sge i64 %r121, 0
  %r122 = zext i1 %r123 to i64
  %r124 = icmp ne i64 %r122, 0
  %r125 = zext i1 %r124 to i64
  store i64 %r125, i64* @.sc.23
  br label %L176
L176:
  %r119 = load i64, i64* @.sc.23
  store i64 0, i64* @.sc.22
  %r127 = icmp ne i64 %r119, 0
  br i1 %r127, label %L177, label %L178
L177:
  %r128 = load i64, i64* %ptr_sy
  %r129 = load i64, i64* @FB_HEIGHT
  %r131 = icmp slt i64 %r128, %r129
  %r130 = zext i1 %r131 to i64
  %r132 = icmp ne i64 %r130, 0
  %r133 = zext i1 %r132 to i64
  store i64 %r133, i64* @.sc.22
  br label %L178
L178:
  %r126 = load i64, i64* @.sc.22
  %r134 = icmp ne i64 %r126, 0
  br i1 %r134, label %L179, label %L181
L179:
  %r135 = load i64, i64* %ptr_sx
  %r136 = load i64, i64* %ptr_sy
  %r137 = load i64, i64* %ptr_sw
  %r138 = load i64, i64* %ptr_sw
  %r139 = load i64, i64* %ptr_r
  %r140 = load i64, i64* %ptr_g
  %r141 = load i64, i64* %ptr_b
  %r142 = call i64 @draw_rect(i64 %r135, i64 %r136, i64 %r137, i64 %r138, i64 %r139, i64 %r140, i64 %r141)
  br label %L181
L181:
  br label %L169
L169:
  %r143 = load i64, i64* %ptr_col
  %r144 = call i64 @_add(i64 %r143, i64 1)
  store i64 %r144, i64* %ptr_col
  br label %L164
L166:
  %r145 = load i64, i64* %ptr_row
  %r146 = call i64 @_add(i64 %r145, i64 1)
  store i64 %r146, i64* %ptr_row
  br label %L161
L163:
  br label %L160
L160:
  ret i64 0
}
define i64 @draw_zui_string_clipped(i64 %arg_wx, i64 %arg_wy, i64 %arg_nw, i64 %arg_nh, i64 %arg_size_mult, i64 %arg_s, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_wx = alloca i64
  store i64 %arg_wx, i64* %ptr_wx
  %ptr_wy = alloca i64
  store i64 %arg_wy, i64* %ptr_wy
  %ptr_nw = alloca i64
  store i64 %arg_nw, i64* %ptr_nw
  %ptr_nh = alloca i64
  store i64 %arg_nh, i64* %ptr_nh
  %ptr_size_mult = alloca i64
  store i64 %arg_size_mult, i64* %ptr_size_mult
  %ptr_s = alloca i64
  store i64 %arg_s, i64* %ptr_s
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_i = alloca i64
  %ptr_cur_x = alloca i64
  %ptr_cur_y = alloca i64
  %ptr_len = alloca i64
  %ptr_char_w = alloca i64
  %ptr_line_h = alloca i64
  %ptr_c_str = alloca i64
  %ptr_ascii = alloca i64
  store i64 0, i64* %ptr_i
  %r1 = load i64, i64* %ptr_wx
  store i64 %r1, i64* %ptr_cur_x
  %r2 = load i64, i64* %ptr_wy
  store i64 %r2, i64* %ptr_cur_y
  %r3 = load i64, i64* %ptr_s
  %r4 = call i64 @mensura(i64 %r3)
  store i64 %r4, i64* %ptr_len
  %r5 = load i64, i64* %ptr_size_mult
  %r6 = mul i64 9, %r5
  store i64 %r6, i64* %ptr_char_w
  %r7 = load i64, i64* %ptr_size_mult
  %r8 = mul i64 12, %r7
  store i64 %r8, i64* %ptr_line_h
  br label %L182
L182:
  %r9 = load i64, i64* %ptr_i
  %r10 = load i64, i64* %ptr_len
  %r12 = icmp slt i64 %r9, %r10
  %r11 = zext i1 %r12 to i64
  %r13 = icmp ne i64 %r11, 0
  br i1 %r13, label %L183, label %L184
L183:
  %r14 = load i64, i64* %ptr_s
  %r15 = load i64, i64* %ptr_i
  %r16 = call i64 @pars(i64 %r14, i64 %r15, i64 1)
  store i64 %r16, i64* %ptr_c_str
  %r17 = load i64, i64* %ptr_c_str
  %r18 = call i64 @codex(i64 %r17)
  store i64 %r18, i64* %ptr_ascii
  %r19 = load i64, i64* %ptr_cur_x
  %r20 = load i64, i64* %ptr_char_w
  %r21 = call i64 @_add(i64 %r19, i64 %r20)
  %r22 = load i64, i64* %ptr_wx
  %r23 = load i64, i64* %ptr_nw
  %r24 = call i64 @_add(i64 %r22, i64 %r23)
  %r25 = sub i64 %r24, 10
  %r27 = icmp sgt i64 %r21, %r25
  %r26 = zext i1 %r27 to i64
  %r28 = icmp ne i64 %r26, 0
  br i1 %r28, label %L185, label %L187
L185:
  %r29 = load i64, i64* %ptr_wx
  store i64 %r29, i64* %ptr_cur_x
  %r30 = load i64, i64* %ptr_cur_y
  %r31 = load i64, i64* %ptr_line_h
  %r32 = call i64 @_add(i64 %r30, i64 %r31)
  store i64 %r32, i64* %ptr_cur_y
  br label %L187
L187:
  %r33 = load i64, i64* %ptr_cur_y
  %r34 = load i64, i64* %ptr_line_h
  %r35 = call i64 @_add(i64 %r33, i64 %r34)
  %r36 = load i64, i64* %ptr_wy
  %r37 = load i64, i64* %ptr_nh
  %r38 = call i64 @_add(i64 %r36, i64 %r37)
  %r39 = sub i64 %r38, 10
  %r41 = icmp sgt i64 %r35, %r39
  %r40 = zext i1 %r41 to i64
  %r42 = icmp ne i64 %r40, 0
  br i1 %r42, label %L188, label %L189
L188:
  %r43 = load i64, i64* %ptr_len
  store i64 %r43, i64* %ptr_i
  br label %L190
L189:
  %r44 = load i64, i64* %ptr_ascii
  %r45 = call i64 @_eq(i64 %r44, i64 10)
  %r46 = icmp ne i64 %r45, 0
  br i1 %r46, label %L191, label %L192
L191:
  %r47 = load i64, i64* %ptr_wx
  store i64 %r47, i64* %ptr_cur_x
  %r48 = load i64, i64* %ptr_cur_y
  %r49 = load i64, i64* %ptr_line_h
  %r50 = call i64 @_add(i64 %r48, i64 %r49)
  store i64 %r50, i64* %ptr_cur_y
  br label %L193
L192:
  %r51 = load i64, i64* %ptr_cur_x
  %r52 = load i64, i64* %ptr_cur_y
  %r53 = load i64, i64* %ptr_size_mult
  %r54 = load i64, i64* %ptr_ascii
  %r55 = load i64, i64* %ptr_r
  %r56 = load i64, i64* %ptr_g
  %r57 = load i64, i64* %ptr_b
  %r58 = call i64 @draw_zui_char(i64 %r51, i64 %r52, i64 %r53, i64 %r54, i64 %r55, i64 %r56, i64 %r57)
  %r59 = load i64, i64* %ptr_cur_x
  %r60 = load i64, i64* %ptr_char_w
  %r61 = call i64 @_add(i64 %r59, i64 %r60)
  store i64 %r61, i64* %ptr_cur_x
  br label %L193
L193:
  br label %L190
L190:
  %r62 = load i64, i64* %ptr_i
  %r63 = call i64 @_add(i64 %r62, i64 1)
  store i64 %r63, i64* %ptr_i
  br label %L182
L184:
  ret i64 0
}
define i64 @draw_raw_char(i64 %arg_sx, i64 %arg_sy, i64 %arg_size_mult, i64 %arg_ascii_code, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_sx = alloca i64
  store i64 %arg_sx, i64* %ptr_sx
  %ptr_sy = alloca i64
  store i64 %arg_sy, i64* %ptr_sy
  %ptr_size_mult = alloca i64
  store i64 %arg_size_mult, i64* %ptr_size_mult
  %ptr_ascii_code = alloca i64
  store i64 %arg_ascii_code, i64* %ptr_ascii_code
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_font_val = alloca i64
  %ptr_row = alloca i64
  %ptr_col = alloca i64
  %ptr_row_data = alloca i64
  %ptr_bit = alloca i64
  %ptr_px = alloca i64
  %ptr_py = alloca i64
  %r1 = load i64, i64* %ptr_ascii_code
  %r3 = icmp sge i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  store i64 0, i64* @.sc.25
  %r5 = icmp ne i64 %r2, 0
  br i1 %r5, label %L194, label %L195
L194:
  %r6 = load i64, i64* %ptr_ascii_code
  %r8 = icmp slt i64 %r6, 128
  %r7 = zext i1 %r8 to i64
  %r9 = icmp ne i64 %r7, 0
  %r10 = zext i1 %r9 to i64
  store i64 %r10, i64* @.sc.25
  br label %L195
L195:
  %r4 = load i64, i64* @.sc.25
  %r11 = icmp ne i64 %r4, 0
  br i1 %r11, label %L196, label %L198
L196:
  %r12 = load i64, i64* @FONT
  %r13 = load i64, i64* %ptr_ascii_code
  %r14 = call i64 @_get(i64 %r12, i64 %r13)
  store i64 %r14, i64* %ptr_font_val
  store i64 0, i64* %ptr_row
  br label %L199
L199:
  %r15 = load i64, i64* %ptr_row
  %r17 = icmp slt i64 %r15, 8
  %r16 = zext i1 %r17 to i64
  %r18 = icmp ne i64 %r16, 0
  br i1 %r18, label %L200, label %L201
L200:
  store i64 0, i64* %ptr_col
  %r19 = load i64, i64* %ptr_font_val
  %r20 = load i64, i64* %ptr_row
  %r21 = sub i64 7, %r20
  %r22 = mul i64 %r21, 8
  %r23 = lshr i64 %r19, %r22
  %r24 = and i64 %r23, 255
  store i64 %r24, i64* %ptr_row_data
  br label %L202
L202:
  %r25 = load i64, i64* %ptr_col
  %r27 = icmp slt i64 %r25, 8
  %r26 = zext i1 %r27 to i64
  %r28 = icmp ne i64 %r26, 0
  br i1 %r28, label %L203, label %L204
L203:
  %r29 = load i64, i64* %ptr_row_data
  %r30 = load i64, i64* %ptr_col
  %r31 = sub i64 7, %r30
  %r32 = lshr i64 %r29, %r31
  %r33 = and i64 %r32, 1
  store i64 %r33, i64* %ptr_bit
  %r34 = load i64, i64* %ptr_bit
  %r35 = call i64 @_eq(i64 %r34, i64 1)
  %r36 = icmp ne i64 %r35, 0
  br i1 %r36, label %L205, label %L207
L205:
  %r37 = load i64, i64* %ptr_sx
  %r38 = load i64, i64* %ptr_col
  %r39 = load i64, i64* %ptr_size_mult
  %r40 = mul i64 %r38, %r39
  %r41 = call i64 @_add(i64 %r37, i64 %r40)
  store i64 %r41, i64* %ptr_px
  %r42 = load i64, i64* %ptr_sy
  %r43 = load i64, i64* %ptr_row
  %r44 = load i64, i64* %ptr_size_mult
  %r45 = mul i64 %r43, %r44
  %r46 = call i64 @_add(i64 %r42, i64 %r45)
  store i64 %r46, i64* %ptr_py
  %r47 = load i64, i64* %ptr_px
  %r48 = load i64, i64* %ptr_py
  %r49 = load i64, i64* %ptr_size_mult
  %r50 = load i64, i64* %ptr_size_mult
  %r51 = load i64, i64* %ptr_r
  %r52 = load i64, i64* %ptr_g
  %r53 = load i64, i64* %ptr_b
  %r54 = call i64 @draw_rect(i64 %r47, i64 %r48, i64 %r49, i64 %r50, i64 %r51, i64 %r52, i64 %r53)
  br label %L207
L207:
  %r55 = load i64, i64* %ptr_col
  %r56 = call i64 @_add(i64 %r55, i64 1)
  store i64 %r56, i64* %ptr_col
  br label %L202
L204:
  %r57 = load i64, i64* %ptr_row
  %r58 = call i64 @_add(i64 %r57, i64 1)
  store i64 %r58, i64* %ptr_row
  br label %L199
L201:
  br label %L198
L198:
  ret i64 0
}
define i64 @draw_raw_string(i64 %arg_sx, i64 %arg_sy, i64 %arg_size_mult, i64 %arg_s, i64 %arg_r, i64 %arg_g, i64 %arg_b) {
  %ptr_sx = alloca i64
  store i64 %arg_sx, i64* %ptr_sx
  %ptr_sy = alloca i64
  store i64 %arg_sy, i64* %ptr_sy
  %ptr_size_mult = alloca i64
  store i64 %arg_size_mult, i64* %ptr_size_mult
  %ptr_s = alloca i64
  store i64 %arg_s, i64* %ptr_s
  %ptr_r = alloca i64
  store i64 %arg_r, i64* %ptr_r
  %ptr_g = alloca i64
  store i64 %arg_g, i64* %ptr_g
  %ptr_b = alloca i64
  store i64 %arg_b, i64* %ptr_b
  %ptr_i = alloca i64
  %ptr_cur_x = alloca i64
  %ptr_cur_y = alloca i64
  %ptr_len = alloca i64
  %ptr_c_str = alloca i64
  %ptr_ascii = alloca i64
  store i64 0, i64* %ptr_i
  %r1 = load i64, i64* %ptr_sx
  store i64 %r1, i64* %ptr_cur_x
  %r2 = load i64, i64* %ptr_sy
  store i64 %r2, i64* %ptr_cur_y
  %r3 = load i64, i64* %ptr_s
  %r4 = call i64 @mensura(i64 %r3)
  store i64 %r4, i64* %ptr_len
  br label %L208
L208:
  %r5 = load i64, i64* %ptr_i
  %r6 = load i64, i64* %ptr_len
  %r8 = icmp slt i64 %r5, %r6
  %r7 = zext i1 %r8 to i64
  %r9 = icmp ne i64 %r7, 0
  br i1 %r9, label %L209, label %L210
L209:
  %r10 = load i64, i64* %ptr_s
  %r11 = load i64, i64* %ptr_i
  %r12 = call i64 @pars(i64 %r10, i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_c_str
  %r13 = load i64, i64* %ptr_c_str
  %r14 = call i64 @codex(i64 %r13)
  store i64 %r14, i64* %ptr_ascii
  %r15 = load i64, i64* %ptr_ascii
  %r16 = call i64 @_eq(i64 %r15, i64 10)
  %r17 = icmp ne i64 %r16, 0
  br i1 %r17, label %L211, label %L212
L211:
  %r18 = load i64, i64* %ptr_sx
  store i64 %r18, i64* %ptr_cur_x
  %r19 = load i64, i64* %ptr_cur_y
  %r20 = load i64, i64* %ptr_size_mult
  %r21 = mul i64 12, %r20
  %r22 = call i64 @_add(i64 %r19, i64 %r21)
  store i64 %r22, i64* %ptr_cur_y
  br label %L213
L212:
  %r23 = load i64, i64* %ptr_cur_x
  %r24 = load i64, i64* %ptr_cur_y
  %r25 = load i64, i64* %ptr_size_mult
  %r26 = load i64, i64* %ptr_ascii
  %r27 = load i64, i64* %ptr_r
  %r28 = load i64, i64* %ptr_g
  %r29 = load i64, i64* %ptr_b
  %r30 = call i64 @draw_raw_char(i64 %r23, i64 %r24, i64 %r25, i64 %r26, i64 %r27, i64 %r28, i64 %r29)
  %r31 = load i64, i64* %ptr_cur_x
  %r32 = load i64, i64* %ptr_size_mult
  %r33 = mul i64 9, %r32
  %r34 = call i64 @_add(i64 %r31, i64 %r33)
  store i64 %r34, i64* %ptr_cur_x
  br label %L213
L213:
  %r35 = load i64, i64* %ptr_i
  %r36 = call i64 @_add(i64 %r35, i64 1)
  store i64 %r36, i64* %ptr_i
  br label %L208
L210:
  ret i64 0
}
define i64 @write_32(i64 %arg_addr, i64 %arg_val) {
  %ptr_addr = alloca i64
  store i64 %arg_addr, i64* %ptr_addr
  %ptr_val = alloca i64
  store i64 %arg_val, i64* %ptr_val
  %r1 = load i64, i64* %ptr_addr
  %r2 = load i64, i64* %ptr_val
  %r3 = inttoptr i64 %r1 to i32*
  %r4 = trunc i64 %r2 to i32
  store volatile i32 %r4, i32* %r3
  ret i64 0
}
define i64 @pci_read_dword(i64 %arg_bus, i64 %arg_slot, i64 %arg_func, i64 %arg_offset) {
  %ptr_bus = alloca i64
  store i64 %arg_bus, i64* %ptr_bus
  %ptr_slot = alloca i64
  store i64 %arg_slot, i64* %ptr_slot
  %ptr_func = alloca i64
  store i64 %arg_func, i64* %ptr_func
  %ptr_offset = alloca i64
  store i64 %arg_offset, i64* %ptr_offset
  %ptr_address = alloca i64
  %r1 = shl i64 1, 31
  %r2 = load i64, i64* %ptr_bus
  %r3 = shl i64 %r2, 16
  %r4 = or i64 %r1, %r3
  %r5 = load i64, i64* %ptr_slot
  %r6 = shl i64 %r5, 11
  %r7 = or i64 %r4, %r6
  %r8 = load i64, i64* %ptr_func
  %r9 = shl i64 %r8, 8
  %r10 = or i64 %r7, %r9
  %r11 = load i64, i64* %ptr_offset
  %r12 = and i64 %r11, 252
  %r13 = or i64 %r10, %r12
  store i64 %r13, i64* %ptr_address
  %r14 = load i64, i64* %ptr_address
  %r15 = trunc i64 3320 to i16
  %r16 = trunc i64 %r14 to i32
  call void asm sideeffect "outl %eax, %dx", "{eax},{dx},~{dirflag},~{fpsr},~{flags}"(i32 %r16, i16 %r15)
  %r17 = trunc i64 3324 to i16
  %r18 = call i32 asm sideeffect "inl %dx, %eax", "={eax},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r17)
  %r19 = zext i32 %r18 to i64
  ret i64 %r19
  ret i64 0
}
define i64 @pci_write_dword(i64 %arg_bus, i64 %arg_slot, i64 %arg_func, i64 %arg_offset, i64 %arg_val) {
  %ptr_bus = alloca i64
  store i64 %arg_bus, i64* %ptr_bus
  %ptr_slot = alloca i64
  store i64 %arg_slot, i64* %ptr_slot
  %ptr_func = alloca i64
  store i64 %arg_func, i64* %ptr_func
  %ptr_offset = alloca i64
  store i64 %arg_offset, i64* %ptr_offset
  %ptr_val = alloca i64
  store i64 %arg_val, i64* %ptr_val
  %ptr_address = alloca i64
  %r1 = shl i64 1, 31
  %r2 = load i64, i64* %ptr_bus
  %r3 = shl i64 %r2, 16
  %r4 = or i64 %r1, %r3
  %r5 = load i64, i64* %ptr_slot
  %r6 = shl i64 %r5, 11
  %r7 = or i64 %r4, %r6
  %r8 = load i64, i64* %ptr_func
  %r9 = shl i64 %r8, 8
  %r10 = or i64 %r7, %r9
  %r11 = load i64, i64* %ptr_offset
  %r12 = and i64 %r11, 252
  %r13 = or i64 %r10, %r12
  store i64 %r13, i64* %ptr_address
  %r14 = load i64, i64* %ptr_address
  %r15 = trunc i64 3320 to i16
  %r16 = trunc i64 %r14 to i32
  call void asm sideeffect "outl %eax, %dx", "{eax},{dx},~{dirflag},~{fpsr},~{flags}"(i32 %r16, i16 %r15)
  %r17 = load i64, i64* %ptr_val
  %r18 = trunc i64 3324 to i16
  %r19 = trunc i64 %r17 to i32
  call void asm sideeffect "outl %eax, %dx", "{eax},{dx},~{dirflag},~{fpsr},~{flags}"(i32 %r19, i16 %r18)
  ret i64 0
}
define i64 @pci_get_vendor(i64 %arg_bus, i64 %arg_slot) {
  %ptr_bus = alloca i64
  store i64 %arg_bus, i64* %ptr_bus
  %ptr_slot = alloca i64
  store i64 %arg_slot, i64* %ptr_slot
  %r1 = load i64, i64* %ptr_bus
  %r2 = load i64, i64* %ptr_slot
  %r3 = call i64 @pci_read_dword(i64 %r1, i64 %r2, i64 0, i64 0)
  %r4 = and i64 %r3, 65535
  ret i64 %r4
  ret i64 0
}
define i64 @pci_get_device(i64 %arg_bus, i64 %arg_slot) {
  %ptr_bus = alloca i64
  store i64 %arg_bus, i64* %ptr_bus
  %ptr_slot = alloca i64
  store i64 %arg_slot, i64* %ptr_slot
  %r1 = load i64, i64* %ptr_bus
  %r2 = load i64, i64* %ptr_slot
  %r3 = call i64 @pci_read_dword(i64 %r1, i64 %r2, i64 0, i64 0)
  %r4 = lshr i64 %r3, 16
  %r5 = and i64 %r4, 65535
  ret i64 %r5
  ret i64 0
}
define i64 @init_e1000(i64 %arg_bus, i64 %arg_slot) {
  %ptr_bus = alloca i64
  store i64 %arg_bus, i64* %ptr_bus
  %ptr_slot = alloca i64
  store i64 %arg_slot, i64* %ptr_slot
  %ptr_bar0 = alloca i64
  %ptr_cmd1 = alloca i64
  %ptr_ctrl = alloca i64
  %ptr_delay = alloca i64
  %ptr_cmd2 = alloca i64
  %ptr_ctrl2 = alloca i64
  %ptr_m_idx = alloca i64
  %r1 = load i64, i64* %ptr_bus
  %r2 = load i64, i64* %ptr_slot
  %r3 = call i64 @pci_read_dword(i64 %r1, i64 %r2, i64 0, i64 16)
  store i64 %r3, i64* %ptr_bar0
  %r4 = load i64, i64* %ptr_bar0
  %r5 = and i64 %r4, 4294967280
  store i64 %r5, i64* @E1000_BAR
  %r6 = load i64, i64* %ptr_bus
  %r7 = load i64, i64* %ptr_slot
  %r8 = call i64 @pci_read_dword(i64 %r6, i64 %r7, i64 0, i64 4)
  store i64 %r8, i64* %ptr_cmd1
  %r9 = load i64, i64* %ptr_bus
  %r10 = load i64, i64* %ptr_slot
  %r11 = load i64, i64* %ptr_cmd1
  %r12 = or i64 %r11, 6
  %r13 = call i64 @pci_write_dword(i64 %r9, i64 %r10, i64 0, i64 4, i64 %r12)
  %r14 = load i64, i64* @E1000_BAR
  %r15 = inttoptr i64 %r14 to i32*
  %r16 = load volatile i32, i32* %r15
  %r17 = zext i32 %r16 to i64
  store i64 %r17, i64* %ptr_ctrl
  %r18 = load i64, i64* @E1000_BAR
  %r19 = load i64, i64* %ptr_ctrl
  %r20 = or i64 %r19, 67108864
  %r21 = inttoptr i64 %r18 to i32*
  %r22 = trunc i64 %r20 to i32
  store volatile i32 %r22, i32* %r21
  store i64 100000, i64* %ptr_delay
  br label %L214
L214:
  %r23 = load i64, i64* %ptr_delay
  %r25 = icmp sgt i64 %r23, 0
  %r24 = zext i1 %r25 to i64
  %r26 = icmp ne i64 %r24, 0
  br i1 %r26, label %L215, label %L216
L215:
  %r27 = trunc i64 3324 to i16
  %r28 = call i32 asm sideeffect "inl %dx, %eax", "={eax},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r27)
  %r29 = zext i32 %r28 to i64
  %r30 = load i64, i64* %ptr_delay
  %r31 = sub i64 %r30, 1
  store i64 %r31, i64* %ptr_delay
  br label %L214
L216:
  %r32 = load i64, i64* %ptr_bus
  %r33 = load i64, i64* %ptr_slot
  %r34 = call i64 @pci_read_dword(i64 %r32, i64 %r33, i64 0, i64 4)
  store i64 %r34, i64* %ptr_cmd2
  %r35 = load i64, i64* %ptr_bus
  %r36 = load i64, i64* %ptr_slot
  %r37 = load i64, i64* %ptr_cmd2
  %r38 = or i64 %r37, 6
  %r39 = call i64 @pci_write_dword(i64 %r35, i64 %r36, i64 0, i64 4, i64 %r38)
  %r40 = load i64, i64* @E1000_BAR
  %r41 = add i64 %r40, 216
  %r42 = inttoptr i64 %r41 to i32*
  %r43 = trunc i64 4294967295 to i32
  store volatile i32 %r43, i32* %r42
  %r44 = load i64, i64* @E1000_BAR
  %r45 = inttoptr i64 %r44 to i32*
  %r46 = load volatile i32, i32* %r45
  %r47 = zext i32 %r46 to i64
  store i64 %r47, i64* %ptr_ctrl2
  %r48 = load i64, i64* @E1000_BAR
  %r49 = load i64, i64* %ptr_ctrl2
  %r50 = or i64 %r49, 97
  %r51 = inttoptr i64 %r48 to i32*
  %r52 = trunc i64 %r50 to i32
  store volatile i32 %r52, i32* %r51
  store i64 0, i64* %ptr_m_idx
  br label %L217
L217:
  %r53 = load i64, i64* %ptr_m_idx
  %r55 = icmp slt i64 %r53, 128
  %r54 = zext i1 %r55 to i64
  %r56 = icmp ne i64 %r54, 0
  br i1 %r56, label %L218, label %L219
L218:
  %r57 = load i64, i64* @E1000_BAR
  %r58 = load i64, i64* %ptr_m_idx
  %r59 = mul i64 %r58, 4
  %r60 = call i64 @_add(i64 20992, i64 %r59)
  %r61 = add i64 %r57, %r60
  %r62 = inttoptr i64 %r61 to i32*
  %r63 = trunc i64 0 to i32
  store volatile i32 %r63, i32* %r62
  %r64 = load i64, i64* %ptr_m_idx
  %r65 = call i64 @_add(i64 %r64, i64 1)
  store i64 %r65, i64* %ptr_m_idx
  br label %L217
L219:
  %r66 = load i64, i64* @E1000_BAR
  %r67 = add i64 %r66, 256
  %r68 = inttoptr i64 %r67 to i32*
  %r69 = trunc i64 0 to i32
  store volatile i32 %r69, i32* %r68
  %r70 = load i64, i64* @E1000_BAR
  ret i64 %r70
  ret i64 0
}
define i64 @get_mac_address() {
  %ptr_ral = alloca i64
  %ptr_rah = alloca i64
  %ptr_m1 = alloca i64
  %ptr_m2 = alloca i64
  %ptr_m3 = alloca i64
  %ptr_m4 = alloca i64
  %ptr_m5 = alloca i64
  %ptr_m6 = alloca i64
  %r1 = load i64, i64* @E1000_BAR
  %r2 = add i64 %r1, 21504
  %r3 = inttoptr i64 %r2 to i32*
  %r4 = load volatile i32, i32* %r3
  %r5 = zext i32 %r4 to i64
  store i64 %r5, i64* %ptr_ral
  %r6 = load i64, i64* @E1000_BAR
  %r7 = add i64 %r6, 21508
  %r8 = inttoptr i64 %r7 to i32*
  %r9 = load volatile i32, i32* %r8
  %r10 = zext i32 %r9 to i64
  store i64 %r10, i64* %ptr_rah
  %r11 = load i64, i64* %ptr_ral
  %r12 = and i64 %r11, 255
  %r13 = call i64 @int_to_str(i64 %r12)
  store i64 %r13, i64* %ptr_m1
  %r14 = load i64, i64* %ptr_ral
  %r15 = lshr i64 %r14, 8
  %r16 = and i64 %r15, 255
  %r17 = call i64 @int_to_str(i64 %r16)
  store i64 %r17, i64* %ptr_m2
  %r18 = load i64, i64* %ptr_ral
  %r19 = lshr i64 %r18, 16
  %r20 = and i64 %r19, 255
  %r21 = call i64 @int_to_str(i64 %r20)
  store i64 %r21, i64* %ptr_m3
  %r22 = load i64, i64* %ptr_ral
  %r23 = lshr i64 %r22, 24
  %r24 = and i64 %r23, 255
  %r25 = call i64 @int_to_str(i64 %r24)
  store i64 %r25, i64* %ptr_m4
  %r26 = load i64, i64* %ptr_rah
  %r27 = and i64 %r26, 255
  %r28 = call i64 @int_to_str(i64 %r27)
  store i64 %r28, i64* %ptr_m5
  %r29 = load i64, i64* %ptr_rah
  %r30 = lshr i64 %r29, 8
  %r31 = and i64 %r30, 255
  %r32 = call i64 @int_to_str(i64 %r31)
  store i64 %r32, i64* %ptr_m6
  %r33 = load i64, i64* %ptr_m1
  %r34 = getelementptr [2 x i8], [2 x i8]* @.str.26, i64 0, i64 0
  %r35 = ptrtoint i8* %r34 to i64
  %r36 = call i64 @_add(i64 %r33, i64 %r35)
  %r37 = load i64, i64* %ptr_m2
  %r38 = call i64 @_add(i64 %r36, i64 %r37)
  %r39 = getelementptr [2 x i8], [2 x i8]* @.str.27, i64 0, i64 0
  %r40 = ptrtoint i8* %r39 to i64
  %r41 = call i64 @_add(i64 %r38, i64 %r40)
  %r42 = load i64, i64* %ptr_m3
  %r43 = call i64 @_add(i64 %r41, i64 %r42)
  %r44 = getelementptr [2 x i8], [2 x i8]* @.str.28, i64 0, i64 0
  %r45 = ptrtoint i8* %r44 to i64
  %r46 = call i64 @_add(i64 %r43, i64 %r45)
  %r47 = load i64, i64* %ptr_m4
  %r48 = call i64 @_add(i64 %r46, i64 %r47)
  %r49 = getelementptr [2 x i8], [2 x i8]* @.str.29, i64 0, i64 0
  %r50 = ptrtoint i8* %r49 to i64
  %r51 = call i64 @_add(i64 %r48, i64 %r50)
  %r52 = load i64, i64* %ptr_m5
  %r53 = call i64 @_add(i64 %r51, i64 %r52)
  %r54 = getelementptr [2 x i8], [2 x i8]* @.str.30, i64 0, i64 0
  %r55 = ptrtoint i8* %r54 to i64
  %r56 = call i64 @_add(i64 %r53, i64 %r55)
  %r57 = load i64, i64* %ptr_m6
  %r58 = call i64 @_add(i64 %r56, i64 %r57)
  ret i64 %r58
  ret i64 0
}
define i64 @init_e1000_tx() {
  %r1 = call i64 @malloc(i64 512)
  store i64 %r1, i64* @E1000_TX_DESC
  %r2 = load i64, i64* @E1000_TX_DESC
  %r3 = call i64 @fast_fill32(i64 %r2, i64 0, i64 128)
  %r4 = load i64, i64* @E1000_BAR
  %r5 = add i64 %r4, 14336
  %r6 = load i64, i64* @E1000_TX_DESC
  %r7 = inttoptr i64 %r5 to i32*
  %r8 = trunc i64 %r6 to i32
  store volatile i32 %r8, i32* %r7
  %r9 = load i64, i64* @E1000_BAR
  %r10 = add i64 %r9, 14340
  %r11 = inttoptr i64 %r10 to i32*
  %r12 = trunc i64 0 to i32
  store volatile i32 %r12, i32* %r11
  %r13 = load i64, i64* @E1000_BAR
  %r14 = add i64 %r13, 14344
  %r15 = inttoptr i64 %r14 to i32*
  %r16 = trunc i64 512 to i32
  store volatile i32 %r16, i32* %r15
  %r17 = load i64, i64* @E1000_BAR
  %r18 = add i64 %r17, 14352
  %r19 = inttoptr i64 %r18 to i32*
  %r20 = trunc i64 0 to i32
  store volatile i32 %r20, i32* %r19
  %r21 = load i64, i64* @E1000_BAR
  %r22 = add i64 %r21, 14360
  %r23 = inttoptr i64 %r22 to i32*
  %r24 = trunc i64 0 to i32
  store volatile i32 %r24, i32* %r23
  store i64 0, i64* @E1000_TX_TAIL
  %r25 = load i64, i64* @E1000_BAR
  %r26 = add i64 %r25, 14376
  %r27 = inttoptr i64 %r26 to i32*
  %r28 = trunc i64 16842752 to i32
  store volatile i32 %r28, i32* %r27
  %r29 = load i64, i64* @E1000_BAR
  %r30 = add i64 %r29, 1040
  %r31 = inttoptr i64 %r30 to i32*
  %r32 = trunc i64 6299658 to i32
  store volatile i32 %r32, i32* %r31
  %r33 = load i64, i64* @E1000_BAR
  %r34 = add i64 %r33, 1024
  %r35 = inttoptr i64 %r34 to i32*
  %r36 = trunc i64 262394 to i32
  store volatile i32 %r36, i32* %r35
  ret i64 0
}
define i64 @init_e1000_rx() {
  %ptr_i = alloca i64
  %ptr_pkt_buf = alloca i64
  %ptr_desc_addr = alloca i64
  %r1 = call i64 @malloc(i64 512)
  store i64 %r1, i64* @E1000_RX_DESC
  %r2 = load i64, i64* @E1000_RX_DESC
  %r3 = call i64 @fast_fill32(i64 %r2, i64 0, i64 128)
  store i64 0, i64* %ptr_i
  br label %L220
L220:
  %r4 = load i64, i64* %ptr_i
  %r6 = icmp slt i64 %r4, 32
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L221, label %L222
L221:
  %r8 = call i64 @malloc(i64 2048)
  store i64 %r8, i64* %ptr_pkt_buf
  %r9 = load i64, i64* @E1000_RX_DESC
  %r10 = load i64, i64* %ptr_i
  %r11 = mul i64 %r10, 16
  %r12 = add i64 %r9, %r11
  store i64 %r12, i64* %ptr_desc_addr
  %r13 = load i64, i64* %ptr_desc_addr
  %r14 = load i64, i64* %ptr_pkt_buf
  %r15 = inttoptr i64 %r13 to i32*
  %r16 = trunc i64 %r14 to i32
  store volatile i32 %r16, i32* %r15
  %r17 = load i64, i64* %ptr_desc_addr
  %r18 = add i64 %r17, 4
  %r19 = inttoptr i64 %r18 to i32*
  %r20 = trunc i64 0 to i32
  store volatile i32 %r20, i32* %r19
  %r21 = load i64, i64* %ptr_i
  %r22 = call i64 @_add(i64 %r21, i64 1)
  store i64 %r22, i64* %ptr_i
  br label %L220
L222:
  %r23 = load i64, i64* @E1000_BAR
  %r24 = add i64 %r23, 10240
  %r25 = load i64, i64* @E1000_RX_DESC
  %r26 = inttoptr i64 %r24 to i32*
  %r27 = trunc i64 %r25 to i32
  store volatile i32 %r27, i32* %r26
  %r28 = load i64, i64* @E1000_BAR
  %r29 = add i64 %r28, 10244
  %r30 = inttoptr i64 %r29 to i32*
  %r31 = trunc i64 0 to i32
  store volatile i32 %r31, i32* %r30
  %r32 = load i64, i64* @E1000_BAR
  %r33 = add i64 %r32, 10248
  %r34 = inttoptr i64 %r33 to i32*
  %r35 = trunc i64 512 to i32
  store volatile i32 %r35, i32* %r34
  %r36 = load i64, i64* @E1000_BAR
  %r37 = add i64 %r36, 10256
  %r38 = inttoptr i64 %r37 to i32*
  %r39 = trunc i64 0 to i32
  store volatile i32 %r39, i32* %r38
  %r40 = load i64, i64* @E1000_BAR
  %r41 = add i64 %r40, 10264
  %r42 = inttoptr i64 %r41 to i32*
  %r43 = trunc i64 31 to i32
  store volatile i32 %r43, i32* %r42
  store i64 0, i64* @E1000_RX_CUR
  %r44 = load i64, i64* @E1000_BAR
  %r45 = add i64 %r44, 256
  %r46 = inttoptr i64 %r45 to i32*
  %r47 = trunc i64 67141658 to i32
  store volatile i32 %r47, i32* %r46
  ret i64 0
}
define i64 @e1000_transmit(i64 %arg_packet_ptr, i64 %arg_length) {
  %ptr_packet_ptr = alloca i64
  store i64 %arg_packet_ptr, i64* %ptr_packet_ptr
  %ptr_length = alloca i64
  store i64 %arg_length, i64* %ptr_length
  %ptr_desc_addr = alloca i64
  %ptr_cmd_len = alloca i64
  %r1 = load i64, i64* @E1000_TX_DESC
  %r2 = load i64, i64* @E1000_TX_TAIL
  %r3 = mul i64 %r2, 16
  %r4 = add i64 %r1, %r3
  store i64 %r4, i64* %ptr_desc_addr
  %r5 = load i64, i64* %ptr_desc_addr
  %r6 = load i64, i64* %ptr_packet_ptr
  %r7 = inttoptr i64 %r5 to i32*
  %r8 = trunc i64 %r6 to i32
  store volatile i32 %r8, i32* %r7
  %r9 = load i64, i64* %ptr_desc_addr
  %r10 = add i64 %r9, 4
  %r11 = inttoptr i64 %r10 to i32*
  %r12 = trunc i64 0 to i32
  store volatile i32 %r12, i32* %r11
  %r13 = load i64, i64* %ptr_length
  %r14 = or i64 %r13, 184549376
  store i64 %r14, i64* %ptr_cmd_len
  %r15 = load i64, i64* %ptr_desc_addr
  %r16 = add i64 %r15, 8
  %r17 = load i64, i64* %ptr_cmd_len
  %r18 = inttoptr i64 %r16 to i32*
  %r19 = trunc i64 %r17 to i32
  store volatile i32 %r19, i32* %r18
  %r20 = load i64, i64* %ptr_desc_addr
  %r21 = add i64 %r20, 12
  %r22 = inttoptr i64 %r21 to i32*
  %r23 = trunc i64 0 to i32
  store volatile i32 %r23, i32* %r22
  %r24 = load i64, i64* @E1000_TX_TAIL
  %r25 = call i64 @_add(i64 %r24, i64 1)
  %r26 = srem i64 %r25, 32
  store i64 %r26, i64* @E1000_TX_TAIL
  %r27 = load i64, i64* @E1000_BAR
  %r28 = add i64 %r27, 14360
  %r29 = load i64, i64* @E1000_TX_TAIL
  %r30 = inttoptr i64 %r28 to i32*
  %r31 = trunc i64 %r29 to i32
  store volatile i32 %r31, i32* %r30
  %r32 = load i64, i64* %ptr_desc_addr
  %r33 = add i64 %r32, 12
  ret i64 %r33
  ret i64 0
}
define i64 @copy_mem(i64 %arg_dst, i64 %arg_src, i64 %arg_len) {
  %ptr_dst = alloca i64
  store i64 %arg_dst, i64* %ptr_dst
  %ptr_src = alloca i64
  store i64 %arg_src, i64* %ptr_src
  %ptr_len = alloca i64
  store i64 %arg_len, i64* %ptr_len
  %ptr_i = alloca i64
  store i64 0, i64* %ptr_i
  br label %L223
L223:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* %ptr_len
  %r4 = icmp slt i64 %r1, %r2
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L224, label %L225
L224:
  %r6 = load i64, i64* %ptr_dst
  %r7 = load i64, i64* %ptr_i
  %r8 = add i64 %r6, %r7
  %r9 = load i64, i64* %ptr_src
  %r10 = load i64, i64* %ptr_i
  %r11 = add i64 %r9, %r10
  %r12 = inttoptr i64 %r11 to ptr
  %r13 = load volatile i8, ptr %r12
  %r14 = zext i8 %r13 to i64
  %r15 = inttoptr i64 %r8 to ptr
  %r16 = trunc i64 %r14 to i8
  store volatile i8 %r16, ptr %r15
  %r17 = load i64, i64* %ptr_i
  %r18 = call i64 @_add(i64 %r17, i64 1)
  store i64 %r18, i64* %ptr_i
  br label %L223
L225:
  ret i64 0
}
define i64 @net_checksum(i64 %arg_addr, i64 %arg_len) {
  %ptr_addr = alloca i64
  store i64 %arg_addr, i64* %ptr_addr
  %ptr_len = alloca i64
  store i64 %arg_len, i64* %ptr_len
  %ptr_sum = alloca i64
  %ptr_i = alloca i64
  %ptr_b1 = alloca i64
  %ptr_b2 = alloca i64
  %ptr_fold1 = alloca i64
  %ptr_fold2 = alloca i64
  store i64 0, i64* %ptr_sum
  store i64 0, i64* %ptr_i
  br label %L226
L226:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* %ptr_len
  %r4 = icmp slt i64 %r1, %r2
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L227, label %L228
L227:
  %r6 = load i64, i64* %ptr_addr
  %r7 = load i64, i64* %ptr_i
  %r8 = add i64 %r6, %r7
  %r9 = inttoptr i64 %r8 to ptr
  %r10 = load volatile i8, ptr %r9
  %r11 = zext i8 %r10 to i64
  %r12 = and i64 %r11, 255
  store i64 %r12, i64* %ptr_b1
  store i64 0, i64* %ptr_b2
  %r13 = load i64, i64* %ptr_i
  %r14 = call i64 @_add(i64 %r13, i64 1)
  %r15 = load i64, i64* %ptr_len
  %r17 = icmp slt i64 %r14, %r15
  %r16 = zext i1 %r17 to i64
  %r18 = icmp ne i64 %r16, 0
  br i1 %r18, label %L229, label %L231
L229:
  %r19 = load i64, i64* %ptr_addr
  %r20 = load i64, i64* %ptr_i
  %r21 = call i64 @_add(i64 %r20, i64 1)
  %r22 = add i64 %r19, %r21
  %r23 = inttoptr i64 %r22 to ptr
  %r24 = load volatile i8, ptr %r23
  %r25 = zext i8 %r24 to i64
  %r26 = and i64 %r25, 255
  store i64 %r26, i64* %ptr_b2
  br label %L231
L231:
  %r27 = load i64, i64* %ptr_sum
  %r28 = load i64, i64* %ptr_b1
  %r29 = shl i64 %r28, 8
  %r30 = load i64, i64* %ptr_b2
  %r31 = or i64 %r29, %r30
  %r32 = call i64 @_add(i64 %r27, i64 %r31)
  store i64 %r32, i64* %ptr_sum
  %r33 = load i64, i64* %ptr_i
  %r34 = call i64 @_add(i64 %r33, i64 2)
  store i64 %r34, i64* %ptr_i
  br label %L226
L228:
  %r35 = load i64, i64* %ptr_sum
  %r36 = and i64 %r35, 65535
  %r37 = load i64, i64* %ptr_sum
  %r38 = lshr i64 %r37, 16
  %r39 = call i64 @_add(i64 %r36, i64 %r38)
  store i64 %r39, i64* %ptr_fold1
  %r40 = load i64, i64* %ptr_fold1
  %r41 = and i64 %r40, 65535
  %r42 = load i64, i64* %ptr_fold1
  %r43 = lshr i64 %r42, 16
  %r44 = call i64 @_add(i64 %r41, i64 %r43)
  store i64 %r44, i64* %ptr_fold2
  %r45 = load i64, i64* %ptr_fold2
  %r46 = xor i64 %r45, 65535
  %r47 = and i64 %r46, 65535
  ret i64 %r47
  ret i64 0
}
define i64 @tcp_checksum(i64 %arg_ip_addr, i64 %arg_tcp_addr, i64 %arg_tcp_len) {
  %ptr_ip_addr = alloca i64
  store i64 %arg_ip_addr, i64* %ptr_ip_addr
  %ptr_tcp_addr = alloca i64
  store i64 %arg_tcp_addr, i64* %ptr_tcp_addr
  %ptr_tcp_len = alloca i64
  store i64 %arg_tcp_len, i64* %ptr_tcp_len
  %ptr_sum = alloca i64
  %ptr_pw1 = alloca i64
  %ptr_pw2 = alloca i64
  %ptr_pw3 = alloca i64
  %ptr_pw4 = alloca i64
  %ptr_i = alloca i64
  %ptr_b1 = alloca i64
  %ptr_b2 = alloca i64
  store i64 0, i64* %ptr_sum
  %r1 = load i64, i64* %ptr_ip_addr
  %r2 = add i64 %r1, 12
  %r3 = inttoptr i64 %r2 to ptr
  %r4 = load volatile i8, ptr %r3
  %r5 = zext i8 %r4 to i64
  %r6 = and i64 %r5, 255
  %r7 = shl i64 %r6, 8
  %r8 = load i64, i64* %ptr_ip_addr
  %r9 = add i64 %r8, 13
  %r10 = inttoptr i64 %r9 to ptr
  %r11 = load volatile i8, ptr %r10
  %r12 = zext i8 %r11 to i64
  %r13 = and i64 %r12, 255
  %r14 = or i64 %r7, %r13
  store i64 %r14, i64* %ptr_pw1
  %r15 = load i64, i64* %ptr_ip_addr
  %r16 = add i64 %r15, 14
  %r17 = inttoptr i64 %r16 to ptr
  %r18 = load volatile i8, ptr %r17
  %r19 = zext i8 %r18 to i64
  %r20 = and i64 %r19, 255
  %r21 = shl i64 %r20, 8
  %r22 = load i64, i64* %ptr_ip_addr
  %r23 = add i64 %r22, 15
  %r24 = inttoptr i64 %r23 to ptr
  %r25 = load volatile i8, ptr %r24
  %r26 = zext i8 %r25 to i64
  %r27 = and i64 %r26, 255
  %r28 = or i64 %r21, %r27
  store i64 %r28, i64* %ptr_pw2
  %r29 = load i64, i64* %ptr_ip_addr
  %r30 = add i64 %r29, 16
  %r31 = inttoptr i64 %r30 to ptr
  %r32 = load volatile i8, ptr %r31
  %r33 = zext i8 %r32 to i64
  %r34 = and i64 %r33, 255
  %r35 = shl i64 %r34, 8
  %r36 = load i64, i64* %ptr_ip_addr
  %r37 = add i64 %r36, 17
  %r38 = inttoptr i64 %r37 to ptr
  %r39 = load volatile i8, ptr %r38
  %r40 = zext i8 %r39 to i64
  %r41 = and i64 %r40, 255
  %r42 = or i64 %r35, %r41
  store i64 %r42, i64* %ptr_pw3
  %r43 = load i64, i64* %ptr_ip_addr
  %r44 = add i64 %r43, 18
  %r45 = inttoptr i64 %r44 to ptr
  %r46 = load volatile i8, ptr %r45
  %r47 = zext i8 %r46 to i64
  %r48 = and i64 %r47, 255
  %r49 = shl i64 %r48, 8
  %r50 = load i64, i64* %ptr_ip_addr
  %r51 = add i64 %r50, 19
  %r52 = inttoptr i64 %r51 to ptr
  %r53 = load volatile i8, ptr %r52
  %r54 = zext i8 %r53 to i64
  %r55 = and i64 %r54, 255
  %r56 = or i64 %r49, %r55
  store i64 %r56, i64* %ptr_pw4
  %r57 = load i64, i64* %ptr_sum
  %r58 = load i64, i64* %ptr_pw1
  %r59 = call i64 @_add(i64 %r57, i64 %r58)
  %r60 = load i64, i64* %ptr_pw2
  %r61 = call i64 @_add(i64 %r59, i64 %r60)
  %r62 = load i64, i64* %ptr_pw3
  %r63 = call i64 @_add(i64 %r61, i64 %r62)
  %r64 = load i64, i64* %ptr_pw4
  %r65 = call i64 @_add(i64 %r63, i64 %r64)
  %r66 = call i64 @_add(i64 %r65, i64 6)
  %r67 = load i64, i64* %ptr_tcp_len
  %r68 = call i64 @_add(i64 %r66, i64 %r67)
  store i64 %r68, i64* %ptr_sum
  store i64 0, i64* %ptr_i
  br label %L232
L232:
  %r69 = load i64, i64* %ptr_i
  %r70 = load i64, i64* %ptr_tcp_len
  %r72 = icmp slt i64 %r69, %r70
  %r71 = zext i1 %r72 to i64
  %r73 = icmp ne i64 %r71, 0
  br i1 %r73, label %L233, label %L234
L233:
  %r74 = load i64, i64* %ptr_tcp_addr
  %r75 = load i64, i64* %ptr_i
  %r76 = add i64 %r74, %r75
  %r77 = inttoptr i64 %r76 to ptr
  %r78 = load volatile i8, ptr %r77
  %r79 = zext i8 %r78 to i64
  %r80 = and i64 %r79, 255
  store i64 %r80, i64* %ptr_b1
  store i64 0, i64* %ptr_b2
  %r81 = load i64, i64* %ptr_i
  %r82 = call i64 @_add(i64 %r81, i64 1)
  %r83 = load i64, i64* %ptr_tcp_len
  %r85 = icmp slt i64 %r82, %r83
  %r84 = zext i1 %r85 to i64
  %r86 = icmp ne i64 %r84, 0
  br i1 %r86, label %L235, label %L237
L235:
  %r87 = load i64, i64* %ptr_tcp_addr
  %r88 = load i64, i64* %ptr_i
  %r89 = call i64 @_add(i64 %r88, i64 1)
  %r90 = add i64 %r87, %r89
  %r91 = inttoptr i64 %r90 to ptr
  %r92 = load volatile i8, ptr %r91
  %r93 = zext i8 %r92 to i64
  %r94 = and i64 %r93, 255
  store i64 %r94, i64* %ptr_b2
  br label %L237
L237:
  %r95 = load i64, i64* %ptr_sum
  %r96 = load i64, i64* %ptr_b1
  %r97 = shl i64 %r96, 8
  %r98 = load i64, i64* %ptr_b2
  %r99 = or i64 %r97, %r98
  %r100 = call i64 @_add(i64 %r95, i64 %r99)
  store i64 %r100, i64* %ptr_sum
  %r101 = load i64, i64* %ptr_i
  %r102 = call i64 @_add(i64 %r101, i64 2)
  store i64 %r102, i64* %ptr_i
  br label %L232
L234:
  br label %L238
L238:
  %r103 = load i64, i64* %ptr_sum
  %r105 = icmp sgt i64 %r103, 65535
  %r104 = zext i1 %r105 to i64
  %r106 = icmp ne i64 %r104, 0
  br i1 %r106, label %L239, label %L240
L239:
  %r107 = load i64, i64* %ptr_sum
  %r108 = and i64 %r107, 65535
  %r109 = load i64, i64* %ptr_sum
  %r110 = lshr i64 %r109, 16
  %r111 = call i64 @_add(i64 %r108, i64 %r110)
  store i64 %r111, i64* %ptr_sum
  br label %L238
L240:
  %r112 = load i64, i64* %ptr_sum
  %r113 = xor i64 %r112, 65535
  %r114 = and i64 %r113, 65535
  ret i64 %r114
  ret i64 0
}
define i64 @e1000_poll_rx() {
  %ptr_desc_addr = alloca i64
  %ptr_status_ptr = alloca i64
  %ptr_status = alloca i64
  %ptr_pkt_ptr = alloca i64
  %ptr_len_low = alloca i64
  %ptr_len_high = alloca i64
  %r1 = load i64, i64* @E1000_RX_DESC
  %r2 = load i64, i64* @E1000_RX_CUR
  %r3 = mul i64 %r2, 16
  %r4 = add i64 %r1, %r3
  store i64 %r4, i64* %ptr_desc_addr
  %r5 = load i64, i64* %ptr_desc_addr
  %r6 = add i64 %r5, 12
  store i64 %r6, i64* %ptr_status_ptr
  %r7 = load i64, i64* %ptr_status_ptr
  %r8 = inttoptr i64 %r7 to ptr
  %r9 = load volatile i8, ptr %r8
  %r10 = zext i8 %r9 to i64
  %r11 = and i64 %r10, 255
  store i64 %r11, i64* %ptr_status
  %r12 = load i64, i64* %ptr_status
  %r13 = srem i64 %r12, 2
  %r14 = call i64 @_eq(i64 %r13, i64 1)
  %r15 = icmp ne i64 %r14, 0
  br i1 %r15, label %L241, label %L243
L241:
  %r16 = load i64, i64* %ptr_desc_addr
  %r17 = inttoptr i64 %r16 to i32*
  %r18 = load volatile i32, i32* %r17
  %r19 = zext i32 %r18 to i64
  store i64 %r19, i64* %ptr_pkt_ptr
  %r20 = load i64, i64* %ptr_desc_addr
  %r21 = add i64 %r20, 8
  %r22 = inttoptr i64 %r21 to ptr
  %r23 = load volatile i8, ptr %r22
  %r24 = zext i8 %r23 to i64
  %r25 = and i64 %r24, 255
  store i64 %r25, i64* %ptr_len_low
  %r26 = load i64, i64* %ptr_desc_addr
  %r27 = add i64 %r26, 9
  %r28 = inttoptr i64 %r27 to ptr
  %r29 = load volatile i8, ptr %r28
  %r30 = zext i8 %r29 to i64
  %r31 = and i64 %r30, 255
  store i64 %r31, i64* %ptr_len_high
  %r32 = load i64, i64* %ptr_len_low
  %r33 = load i64, i64* %ptr_len_high
  %r34 = mul i64 %r33, 256
  %r35 = call i64 @_add(i64 %r32, i64 %r34)
  store i64 %r35, i64* @E1000_RX_LEN
  %r36 = load i64, i64* %ptr_status_ptr
  %r37 = inttoptr i64 %r36 to ptr
  %r38 = trunc i64 0 to i8
  store volatile i8 %r38, ptr %r37
  %r39 = load i64, i64* @E1000_BAR
  %r40 = add i64 %r39, 10264
  %r41 = load i64, i64* @E1000_RX_CUR
  %r42 = inttoptr i64 %r40 to i32*
  %r43 = trunc i64 %r41 to i32
  store volatile i32 %r43, i32* %r42
  %r44 = load i64, i64* @E1000_RX_CUR
  %r45 = call i64 @_add(i64 %r44, i64 1)
  %r46 = srem i64 %r45, 32
  store i64 %r46, i64* @E1000_RX_CUR
  %r47 = load i64, i64* %ptr_pkt_ptr
  ret i64 %r47
  br label %L243
L243:
  ret i64 0
  ret i64 0
}
define i64 @e1000_send_syn(i64 %arg_src_port, i64 %arg_seq) {
  %ptr_src_port = alloca i64
  store i64 %arg_src_port, i64* %ptr_src_port
  %ptr_seq = alloca i64
  store i64 %arg_seq, i64* %ptr_seq
  %ptr_f = alloca i64
  %ptr_z = alloca i64
  %ptr_ip = alloca i64
  %ptr_tcp = alloca i64
  %ptr_ip_csum = alloca i64
  %ptr_pseudo = alloca i64
  %ptr_c_i = alloca i64
  %ptr_tcp_csum = alloca i64
  %ptr_timeout = alloca i64
  %r1 = call i64 @malloc(i64 64)
  store i64 %r1, i64* %ptr_f
  store i64 0, i64* %ptr_z
  br label %L244
L244:
  %r2 = load i64, i64* %ptr_z
  %r4 = icmp slt i64 %r2, 64
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L245, label %L246
L245:
  %r6 = load i64, i64* %ptr_f
  %r7 = load i64, i64* %ptr_z
  %r8 = add i64 %r6, %r7
  %r9 = inttoptr i64 %r8 to ptr
  %r10 = trunc i64 0 to i8
  store volatile i8 %r10, ptr %r9
  %r11 = load i64, i64* %ptr_z
  %r12 = call i64 @_add(i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_z
  br label %L244
L246:
  %r13 = load i64, i64* %ptr_f
  %r14 = add i64 %r13, 0
  %r15 = inttoptr i64 %r14 to ptr
  %r16 = trunc i64 82 to i8
  store volatile i8 %r16, ptr %r15
  %r17 = load i64, i64* %ptr_f
  %r18 = add i64 %r17, 1
  %r19 = inttoptr i64 %r18 to ptr
  %r20 = trunc i64 85 to i8
  store volatile i8 %r20, ptr %r19
  %r21 = load i64, i64* %ptr_f
  %r22 = add i64 %r21, 2
  %r23 = inttoptr i64 %r22 to ptr
  %r24 = trunc i64 10 to i8
  store volatile i8 %r24, ptr %r23
  %r25 = load i64, i64* %ptr_f
  %r26 = add i64 %r25, 3
  %r27 = inttoptr i64 %r26 to ptr
  %r28 = trunc i64 0 to i8
  store volatile i8 %r28, ptr %r27
  %r29 = load i64, i64* %ptr_f
  %r30 = add i64 %r29, 4
  %r31 = inttoptr i64 %r30 to ptr
  %r32 = trunc i64 2 to i8
  store volatile i8 %r32, ptr %r31
  %r33 = load i64, i64* %ptr_f
  %r34 = add i64 %r33, 5
  %r35 = inttoptr i64 %r34 to ptr
  %r36 = trunc i64 2 to i8
  store volatile i8 %r36, ptr %r35
  %r37 = load i64, i64* %ptr_f
  %r38 = add i64 %r37, 6
  %r39 = inttoptr i64 %r38 to ptr
  %r40 = trunc i64 82 to i8
  store volatile i8 %r40, ptr %r39
  %r41 = load i64, i64* %ptr_f
  %r42 = add i64 %r41, 7
  %r43 = inttoptr i64 %r42 to ptr
  %r44 = trunc i64 84 to i8
  store volatile i8 %r44, ptr %r43
  %r45 = load i64, i64* %ptr_f
  %r46 = add i64 %r45, 8
  %r47 = inttoptr i64 %r46 to ptr
  %r48 = trunc i64 0 to i8
  store volatile i8 %r48, ptr %r47
  %r49 = load i64, i64* %ptr_f
  %r50 = add i64 %r49, 9
  %r51 = inttoptr i64 %r50 to ptr
  %r52 = trunc i64 18 to i8
  store volatile i8 %r52, ptr %r51
  %r53 = load i64, i64* %ptr_f
  %r54 = add i64 %r53, 10
  %r55 = inttoptr i64 %r54 to ptr
  %r56 = trunc i64 52 to i8
  store volatile i8 %r56, ptr %r55
  %r57 = load i64, i64* %ptr_f
  %r58 = add i64 %r57, 11
  %r59 = inttoptr i64 %r58 to ptr
  %r60 = trunc i64 86 to i8
  store volatile i8 %r60, ptr %r59
  %r61 = load i64, i64* %ptr_f
  %r62 = add i64 %r61, 12
  %r63 = inttoptr i64 %r62 to ptr
  %r64 = trunc i64 8 to i8
  store volatile i8 %r64, ptr %r63
  %r65 = load i64, i64* %ptr_f
  %r66 = add i64 %r65, 13
  %r67 = inttoptr i64 %r66 to ptr
  %r68 = trunc i64 0 to i8
  store volatile i8 %r68, ptr %r67
  %r69 = load i64, i64* %ptr_f
  %r70 = add i64 %r69, 14
  store i64 %r70, i64* %ptr_ip
  %r71 = load i64, i64* %ptr_ip
  %r72 = add i64 %r71, 0
  %r73 = inttoptr i64 %r72 to ptr
  %r74 = trunc i64 69 to i8
  store volatile i8 %r74, ptr %r73
  %r75 = load i64, i64* %ptr_ip
  %r76 = add i64 %r75, 1
  %r77 = inttoptr i64 %r76 to ptr
  %r78 = trunc i64 0 to i8
  store volatile i8 %r78, ptr %r77
  %r79 = load i64, i64* %ptr_ip
  %r80 = add i64 %r79, 2
  %r81 = inttoptr i64 %r80 to ptr
  %r82 = trunc i64 0 to i8
  store volatile i8 %r82, ptr %r81
  %r83 = load i64, i64* %ptr_ip
  %r84 = add i64 %r83, 3
  %r85 = inttoptr i64 %r84 to ptr
  %r86 = trunc i64 44 to i8
  store volatile i8 %r86, ptr %r85
  %r87 = load i64, i64* %ptr_ip
  %r88 = add i64 %r87, 4
  %r89 = inttoptr i64 %r88 to ptr
  %r90 = trunc i64 17 to i8
  store volatile i8 %r90, ptr %r89
  %r91 = load i64, i64* %ptr_ip
  %r92 = add i64 %r91, 5
  %r93 = inttoptr i64 %r92 to ptr
  %r94 = trunc i64 17 to i8
  store volatile i8 %r94, ptr %r93
  %r95 = load i64, i64* %ptr_ip
  %r96 = add i64 %r95, 6
  %r97 = inttoptr i64 %r96 to ptr
  %r98 = trunc i64 64 to i8
  store volatile i8 %r98, ptr %r97
  %r99 = load i64, i64* %ptr_ip
  %r100 = add i64 %r99, 7
  %r101 = inttoptr i64 %r100 to ptr
  %r102 = trunc i64 0 to i8
  store volatile i8 %r102, ptr %r101
  %r103 = load i64, i64* %ptr_ip
  %r104 = add i64 %r103, 8
  %r105 = inttoptr i64 %r104 to ptr
  %r106 = trunc i64 64 to i8
  store volatile i8 %r106, ptr %r105
  %r107 = load i64, i64* %ptr_ip
  %r108 = add i64 %r107, 9
  %r109 = inttoptr i64 %r108 to ptr
  %r110 = trunc i64 6 to i8
  store volatile i8 %r110, ptr %r109
  %r111 = load i64, i64* %ptr_ip
  %r112 = add i64 %r111, 10
  %r113 = inttoptr i64 %r112 to ptr
  %r114 = trunc i64 0 to i8
  store volatile i8 %r114, ptr %r113
  %r115 = load i64, i64* %ptr_ip
  %r116 = add i64 %r115, 11
  %r117 = inttoptr i64 %r116 to ptr
  %r118 = trunc i64 0 to i8
  store volatile i8 %r118, ptr %r117
  %r119 = load i64, i64* %ptr_ip
  %r120 = add i64 %r119, 12
  %r121 = inttoptr i64 %r120 to ptr
  %r122 = trunc i64 10 to i8
  store volatile i8 %r122, ptr %r121
  %r123 = load i64, i64* %ptr_ip
  %r124 = add i64 %r123, 13
  %r125 = inttoptr i64 %r124 to ptr
  %r126 = trunc i64 0 to i8
  store volatile i8 %r126, ptr %r125
  %r127 = load i64, i64* %ptr_ip
  %r128 = add i64 %r127, 14
  %r129 = inttoptr i64 %r128 to ptr
  %r130 = trunc i64 2 to i8
  store volatile i8 %r130, ptr %r129
  %r131 = load i64, i64* %ptr_ip
  %r132 = add i64 %r131, 15
  %r133 = inttoptr i64 %r132 to ptr
  %r134 = trunc i64 15 to i8
  store volatile i8 %r134, ptr %r133
  %r135 = load i64, i64* %ptr_ip
  %r136 = add i64 %r135, 16
  %r137 = inttoptr i64 %r136 to ptr
  %r138 = trunc i64 1 to i8
  store volatile i8 %r138, ptr %r137
  %r139 = load i64, i64* %ptr_ip
  %r140 = add i64 %r139, 17
  %r141 = inttoptr i64 %r140 to ptr
  %r142 = trunc i64 1 to i8
  store volatile i8 %r142, ptr %r141
  %r143 = load i64, i64* %ptr_ip
  %r144 = add i64 %r143, 18
  %r145 = inttoptr i64 %r144 to ptr
  %r146 = trunc i64 1 to i8
  store volatile i8 %r146, ptr %r145
  %r147 = load i64, i64* %ptr_ip
  %r148 = add i64 %r147, 19
  %r149 = inttoptr i64 %r148 to ptr
  %r150 = trunc i64 1 to i8
  store volatile i8 %r150, ptr %r149
  %r151 = load i64, i64* %ptr_f
  %r152 = add i64 %r151, 34
  store i64 %r152, i64* %ptr_tcp
  %r153 = load i64, i64* %ptr_tcp
  %r154 = add i64 %r153, 0
  %r155 = load i64, i64* %ptr_src_port
  %r156 = lshr i64 %r155, 8
  %r157 = and i64 %r156, 255
  %r158 = inttoptr i64 %r154 to ptr
  %r159 = trunc i64 %r157 to i8
  store volatile i8 %r159, ptr %r158
  %r160 = load i64, i64* %ptr_tcp
  %r161 = add i64 %r160, 1
  %r162 = load i64, i64* %ptr_src_port
  %r163 = and i64 %r162, 255
  %r164 = inttoptr i64 %r161 to ptr
  %r165 = trunc i64 %r163 to i8
  store volatile i8 %r165, ptr %r164
  %r166 = load i64, i64* %ptr_tcp
  %r167 = add i64 %r166, 2
  %r168 = inttoptr i64 %r167 to ptr
  %r169 = trunc i64 0 to i8
  store volatile i8 %r169, ptr %r168
  %r170 = load i64, i64* %ptr_tcp
  %r171 = add i64 %r170, 3
  %r172 = inttoptr i64 %r171 to ptr
  %r173 = trunc i64 80 to i8
  store volatile i8 %r173, ptr %r172
  %r174 = load i64, i64* %ptr_tcp
  %r175 = add i64 %r174, 4
  %r176 = load i64, i64* %ptr_seq
  %r177 = lshr i64 %r176, 24
  %r178 = and i64 %r177, 255
  %r179 = inttoptr i64 %r175 to ptr
  %r180 = trunc i64 %r178 to i8
  store volatile i8 %r180, ptr %r179
  %r181 = load i64, i64* %ptr_tcp
  %r182 = add i64 %r181, 5
  %r183 = load i64, i64* %ptr_seq
  %r184 = lshr i64 %r183, 16
  %r185 = and i64 %r184, 255
  %r186 = inttoptr i64 %r182 to ptr
  %r187 = trunc i64 %r185 to i8
  store volatile i8 %r187, ptr %r186
  %r188 = load i64, i64* %ptr_tcp
  %r189 = add i64 %r188, 6
  %r190 = load i64, i64* %ptr_seq
  %r191 = lshr i64 %r190, 8
  %r192 = and i64 %r191, 255
  %r193 = inttoptr i64 %r189 to ptr
  %r194 = trunc i64 %r192 to i8
  store volatile i8 %r194, ptr %r193
  %r195 = load i64, i64* %ptr_tcp
  %r196 = add i64 %r195, 7
  %r197 = load i64, i64* %ptr_seq
  %r198 = and i64 %r197, 255
  %r199 = inttoptr i64 %r196 to ptr
  %r200 = trunc i64 %r198 to i8
  store volatile i8 %r200, ptr %r199
  %r201 = load i64, i64* %ptr_tcp
  %r202 = add i64 %r201, 8
  %r203 = inttoptr i64 %r202 to ptr
  %r204 = trunc i64 0 to i8
  store volatile i8 %r204, ptr %r203
  %r205 = load i64, i64* %ptr_tcp
  %r206 = add i64 %r205, 9
  %r207 = inttoptr i64 %r206 to ptr
  %r208 = trunc i64 0 to i8
  store volatile i8 %r208, ptr %r207
  %r209 = load i64, i64* %ptr_tcp
  %r210 = add i64 %r209, 10
  %r211 = inttoptr i64 %r210 to ptr
  %r212 = trunc i64 0 to i8
  store volatile i8 %r212, ptr %r211
  %r213 = load i64, i64* %ptr_tcp
  %r214 = add i64 %r213, 11
  %r215 = inttoptr i64 %r214 to ptr
  %r216 = trunc i64 0 to i8
  store volatile i8 %r216, ptr %r215
  %r217 = load i64, i64* %ptr_tcp
  %r218 = add i64 %r217, 12
  %r219 = inttoptr i64 %r218 to ptr
  %r220 = trunc i64 96 to i8
  store volatile i8 %r220, ptr %r219
  %r221 = load i64, i64* %ptr_tcp
  %r222 = add i64 %r221, 13
  %r223 = inttoptr i64 %r222 to ptr
  %r224 = trunc i64 2 to i8
  store volatile i8 %r224, ptr %r223
  %r225 = load i64, i64* %ptr_tcp
  %r226 = add i64 %r225, 14
  %r227 = inttoptr i64 %r226 to ptr
  %r228 = trunc i64 255 to i8
  store volatile i8 %r228, ptr %r227
  %r229 = load i64, i64* %ptr_tcp
  %r230 = add i64 %r229, 15
  %r231 = inttoptr i64 %r230 to ptr
  %r232 = trunc i64 255 to i8
  store volatile i8 %r232, ptr %r231
  %r233 = load i64, i64* %ptr_tcp
  %r234 = add i64 %r233, 16
  %r235 = inttoptr i64 %r234 to ptr
  %r236 = trunc i64 0 to i8
  store volatile i8 %r236, ptr %r235
  %r237 = load i64, i64* %ptr_tcp
  %r238 = add i64 %r237, 17
  %r239 = inttoptr i64 %r238 to ptr
  %r240 = trunc i64 0 to i8
  store volatile i8 %r240, ptr %r239
  %r241 = load i64, i64* %ptr_tcp
  %r242 = add i64 %r241, 18
  %r243 = inttoptr i64 %r242 to ptr
  %r244 = trunc i64 0 to i8
  store volatile i8 %r244, ptr %r243
  %r245 = load i64, i64* %ptr_tcp
  %r246 = add i64 %r245, 19
  %r247 = inttoptr i64 %r246 to ptr
  %r248 = trunc i64 0 to i8
  store volatile i8 %r248, ptr %r247
  %r249 = load i64, i64* %ptr_tcp
  %r250 = add i64 %r249, 20
  %r251 = inttoptr i64 %r250 to ptr
  %r252 = trunc i64 2 to i8
  store volatile i8 %r252, ptr %r251
  %r253 = load i64, i64* %ptr_tcp
  %r254 = add i64 %r253, 21
  %r255 = inttoptr i64 %r254 to ptr
  %r256 = trunc i64 4 to i8
  store volatile i8 %r256, ptr %r255
  %r257 = load i64, i64* %ptr_tcp
  %r258 = add i64 %r257, 22
  %r259 = inttoptr i64 %r258 to ptr
  %r260 = trunc i64 5 to i8
  store volatile i8 %r260, ptr %r259
  %r261 = load i64, i64* %ptr_tcp
  %r262 = add i64 %r261, 23
  %r263 = inttoptr i64 %r262 to ptr
  %r264 = trunc i64 180 to i8
  store volatile i8 %r264, ptr %r263
  call void asm sideeffect "mfence", "~{memory}"()
  %r265 = load i64, i64* %ptr_ip
  %r266 = call i64 @net_checksum(i64 %r265, i64 20)
  store i64 %r266, i64* %ptr_ip_csum
  %r267 = load i64, i64* %ptr_ip
  %r268 = add i64 %r267, 10
  %r269 = load i64, i64* %ptr_ip_csum
  %r270 = lshr i64 %r269, 8
  %r271 = and i64 %r270, 255
  %r272 = inttoptr i64 %r268 to ptr
  %r273 = trunc i64 %r271 to i8
  store volatile i8 %r273, ptr %r272
  %r274 = load i64, i64* %ptr_ip
  %r275 = add i64 %r274, 11
  %r276 = load i64, i64* %ptr_ip_csum
  %r277 = and i64 %r276, 255
  %r278 = inttoptr i64 %r275 to ptr
  %r279 = trunc i64 %r277 to i8
  store volatile i8 %r279, ptr %r278
  %r280 = call i64 @malloc(i64 64)
  store i64 %r280, i64* %ptr_pseudo
  %r281 = load i64, i64* %ptr_pseudo
  %r282 = add i64 %r281, 0
  %r283 = inttoptr i64 %r282 to ptr
  %r284 = trunc i64 10 to i8
  store volatile i8 %r284, ptr %r283
  %r285 = load i64, i64* %ptr_pseudo
  %r286 = add i64 %r285, 1
  %r287 = inttoptr i64 %r286 to ptr
  %r288 = trunc i64 0 to i8
  store volatile i8 %r288, ptr %r287
  %r289 = load i64, i64* %ptr_pseudo
  %r290 = add i64 %r289, 2
  %r291 = inttoptr i64 %r290 to ptr
  %r292 = trunc i64 2 to i8
  store volatile i8 %r292, ptr %r291
  %r293 = load i64, i64* %ptr_pseudo
  %r294 = add i64 %r293, 3
  %r295 = inttoptr i64 %r294 to ptr
  %r296 = trunc i64 15 to i8
  store volatile i8 %r296, ptr %r295
  %r297 = load i64, i64* %ptr_pseudo
  %r298 = add i64 %r297, 4
  %r299 = inttoptr i64 %r298 to ptr
  %r300 = trunc i64 1 to i8
  store volatile i8 %r300, ptr %r299
  %r301 = load i64, i64* %ptr_pseudo
  %r302 = add i64 %r301, 5
  %r303 = inttoptr i64 %r302 to ptr
  %r304 = trunc i64 1 to i8
  store volatile i8 %r304, ptr %r303
  %r305 = load i64, i64* %ptr_pseudo
  %r306 = add i64 %r305, 6
  %r307 = inttoptr i64 %r306 to ptr
  %r308 = trunc i64 1 to i8
  store volatile i8 %r308, ptr %r307
  %r309 = load i64, i64* %ptr_pseudo
  %r310 = add i64 %r309, 7
  %r311 = inttoptr i64 %r310 to ptr
  %r312 = trunc i64 1 to i8
  store volatile i8 %r312, ptr %r311
  %r313 = load i64, i64* %ptr_pseudo
  %r314 = add i64 %r313, 8
  %r315 = inttoptr i64 %r314 to ptr
  %r316 = trunc i64 0 to i8
  store volatile i8 %r316, ptr %r315
  %r317 = load i64, i64* %ptr_pseudo
  %r318 = add i64 %r317, 9
  %r319 = inttoptr i64 %r318 to ptr
  %r320 = trunc i64 6 to i8
  store volatile i8 %r320, ptr %r319
  %r321 = load i64, i64* %ptr_pseudo
  %r322 = add i64 %r321, 10
  %r323 = inttoptr i64 %r322 to ptr
  %r324 = trunc i64 0 to i8
  store volatile i8 %r324, ptr %r323
  %r325 = load i64, i64* %ptr_pseudo
  %r326 = add i64 %r325, 11
  %r327 = inttoptr i64 %r326 to ptr
  %r328 = trunc i64 24 to i8
  store volatile i8 %r328, ptr %r327
  store i64 0, i64* %ptr_c_i
  br label %L247
L247:
  %r329 = load i64, i64* %ptr_c_i
  %r331 = icmp slt i64 %r329, 24
  %r330 = zext i1 %r331 to i64
  %r332 = icmp ne i64 %r330, 0
  br i1 %r332, label %L248, label %L249
L248:
  %r333 = load i64, i64* %ptr_pseudo
  %r334 = load i64, i64* %ptr_c_i
  %r335 = call i64 @_add(i64 12, i64 %r334)
  %r336 = add i64 %r333, %r335
  %r337 = load i64, i64* %ptr_tcp
  %r338 = load i64, i64* %ptr_c_i
  %r339 = add i64 %r337, %r338
  %r340 = inttoptr i64 %r339 to ptr
  %r341 = load volatile i8, ptr %r340
  %r342 = zext i8 %r341 to i64
  %r343 = inttoptr i64 %r336 to ptr
  %r344 = trunc i64 %r342 to i8
  store volatile i8 %r344, ptr %r343
  %r345 = load i64, i64* %ptr_c_i
  %r346 = call i64 @_add(i64 %r345, i64 1)
  store i64 %r346, i64* %ptr_c_i
  br label %L247
L249:
  call void asm sideeffect "mfence", "~{memory}"()
  %r347 = load i64, i64* %ptr_pseudo
  %r348 = call i64 @net_checksum(i64 %r347, i64 36)
  store i64 %r348, i64* %ptr_tcp_csum
  %r349 = load i64, i64* %ptr_tcp
  %r350 = add i64 %r349, 16
  %r351 = load i64, i64* %ptr_tcp_csum
  %r352 = lshr i64 %r351, 8
  %r353 = and i64 %r352, 255
  %r354 = inttoptr i64 %r350 to ptr
  %r355 = trunc i64 %r353 to i8
  store volatile i8 %r355, ptr %r354
  %r356 = load i64, i64* %ptr_tcp
  %r357 = add i64 %r356, 17
  %r358 = load i64, i64* %ptr_tcp_csum
  %r359 = and i64 %r358, 255
  %r360 = inttoptr i64 %r357 to ptr
  %r361 = trunc i64 %r359 to i8
  store volatile i8 %r361, ptr %r360
  call void asm sideeffect "mfence", "~{memory}"()
  %r362 = load i64, i64* %ptr_f
  %r363 = call i64 @e1000_transmit(i64 %r362, i64 64)
  store i64 100000, i64* %ptr_timeout
  br label %L250
L250:
  %r364 = load i64, i64* %ptr_timeout
  %r366 = icmp sgt i64 %r364, 0
  %r365 = zext i1 %r366 to i64
  %r367 = icmp ne i64 %r365, 0
  br i1 %r367, label %L251, label %L252
L251:
  %r368 = load i64, i64* @E1000_BAR
  %r369 = add i64 %r368, 14352
  %r370 = inttoptr i64 %r369 to i32*
  %r371 = load volatile i32, i32* %r370
  %r372 = zext i32 %r371 to i64
  %r373 = load i64, i64* @E1000_TX_TAIL
  %r374 = call i64 @_eq(i64 %r372, i64 %r373)
  %r375 = icmp ne i64 %r374, 0
  br i1 %r375, label %L253, label %L255
L253:
  store i64 0, i64* %ptr_timeout
  br label %L255
L255:
  %r376 = load i64, i64* %ptr_timeout
  %r377 = sub i64 %r376, 1
  store i64 %r377, i64* %ptr_timeout
  br label %L250
L252:
  %r378 = load i64, i64* %ptr_f
  ret i64 %r378
  ret i64 0
}
define i64 @e1000_send_ack(i64 %arg_src_port, i64 %arg_seq, i64 %arg_a1, i64 %arg_a2, i64 %arg_a3, i64 %arg_a4) {
  %ptr_src_port = alloca i64
  store i64 %arg_src_port, i64* %ptr_src_port
  %ptr_seq = alloca i64
  store i64 %arg_seq, i64* %ptr_seq
  %ptr_a1 = alloca i64
  store i64 %arg_a1, i64* %ptr_a1
  %ptr_a2 = alloca i64
  store i64 %arg_a2, i64* %ptr_a2
  %ptr_a3 = alloca i64
  store i64 %arg_a3, i64* %ptr_a3
  %ptr_a4 = alloca i64
  store i64 %arg_a4, i64* %ptr_a4
  %ptr_f = alloca i64
  %ptr_z = alloca i64
  %ptr_ip = alloca i64
  %ptr_tcp = alloca i64
  %ptr_ip_csum = alloca i64
  %ptr_pseudo = alloca i64
  %ptr_c_i = alloca i64
  %ptr_tcp_csum = alloca i64
  %ptr_timeout = alloca i64
  %r1 = call i64 @malloc(i64 64)
  store i64 %r1, i64* %ptr_f
  store i64 0, i64* %ptr_z
  br label %L256
L256:
  %r2 = load i64, i64* %ptr_z
  %r4 = icmp slt i64 %r2, 64
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L257, label %L258
L257:
  %r6 = load i64, i64* %ptr_f
  %r7 = load i64, i64* %ptr_z
  %r8 = add i64 %r6, %r7
  %r9 = inttoptr i64 %r8 to ptr
  %r10 = trunc i64 0 to i8
  store volatile i8 %r10, ptr %r9
  %r11 = load i64, i64* %ptr_z
  %r12 = call i64 @_add(i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_z
  br label %L256
L258:
  %r13 = load i64, i64* %ptr_f
  %r14 = add i64 %r13, 0
  %r15 = inttoptr i64 %r14 to ptr
  %r16 = trunc i64 82 to i8
  store volatile i8 %r16, ptr %r15
  %r17 = load i64, i64* %ptr_f
  %r18 = add i64 %r17, 1
  %r19 = inttoptr i64 %r18 to ptr
  %r20 = trunc i64 85 to i8
  store volatile i8 %r20, ptr %r19
  %r21 = load i64, i64* %ptr_f
  %r22 = add i64 %r21, 2
  %r23 = inttoptr i64 %r22 to ptr
  %r24 = trunc i64 10 to i8
  store volatile i8 %r24, ptr %r23
  %r25 = load i64, i64* %ptr_f
  %r26 = add i64 %r25, 3
  %r27 = inttoptr i64 %r26 to ptr
  %r28 = trunc i64 0 to i8
  store volatile i8 %r28, ptr %r27
  %r29 = load i64, i64* %ptr_f
  %r30 = add i64 %r29, 4
  %r31 = inttoptr i64 %r30 to ptr
  %r32 = trunc i64 2 to i8
  store volatile i8 %r32, ptr %r31
  %r33 = load i64, i64* %ptr_f
  %r34 = add i64 %r33, 5
  %r35 = inttoptr i64 %r34 to ptr
  %r36 = trunc i64 2 to i8
  store volatile i8 %r36, ptr %r35
  %r37 = load i64, i64* %ptr_f
  %r38 = add i64 %r37, 6
  %r39 = inttoptr i64 %r38 to ptr
  %r40 = trunc i64 82 to i8
  store volatile i8 %r40, ptr %r39
  %r41 = load i64, i64* %ptr_f
  %r42 = add i64 %r41, 7
  %r43 = inttoptr i64 %r42 to ptr
  %r44 = trunc i64 84 to i8
  store volatile i8 %r44, ptr %r43
  %r45 = load i64, i64* %ptr_f
  %r46 = add i64 %r45, 8
  %r47 = inttoptr i64 %r46 to ptr
  %r48 = trunc i64 0 to i8
  store volatile i8 %r48, ptr %r47
  %r49 = load i64, i64* %ptr_f
  %r50 = add i64 %r49, 9
  %r51 = inttoptr i64 %r50 to ptr
  %r52 = trunc i64 18 to i8
  store volatile i8 %r52, ptr %r51
  %r53 = load i64, i64* %ptr_f
  %r54 = add i64 %r53, 10
  %r55 = inttoptr i64 %r54 to ptr
  %r56 = trunc i64 52 to i8
  store volatile i8 %r56, ptr %r55
  %r57 = load i64, i64* %ptr_f
  %r58 = add i64 %r57, 11
  %r59 = inttoptr i64 %r58 to ptr
  %r60 = trunc i64 86 to i8
  store volatile i8 %r60, ptr %r59
  %r61 = load i64, i64* %ptr_f
  %r62 = add i64 %r61, 12
  %r63 = inttoptr i64 %r62 to ptr
  %r64 = trunc i64 8 to i8
  store volatile i8 %r64, ptr %r63
  %r65 = load i64, i64* %ptr_f
  %r66 = add i64 %r65, 13
  %r67 = inttoptr i64 %r66 to ptr
  %r68 = trunc i64 0 to i8
  store volatile i8 %r68, ptr %r67
  %r69 = load i64, i64* %ptr_f
  %r70 = add i64 %r69, 14
  store i64 %r70, i64* %ptr_ip
  %r71 = load i64, i64* %ptr_ip
  %r72 = add i64 %r71, 0
  %r73 = inttoptr i64 %r72 to ptr
  %r74 = trunc i64 69 to i8
  store volatile i8 %r74, ptr %r73
  %r75 = load i64, i64* %ptr_ip
  %r76 = add i64 %r75, 1
  %r77 = inttoptr i64 %r76 to ptr
  %r78 = trunc i64 0 to i8
  store volatile i8 %r78, ptr %r77
  %r79 = load i64, i64* %ptr_ip
  %r80 = add i64 %r79, 2
  %r81 = inttoptr i64 %r80 to ptr
  %r82 = trunc i64 0 to i8
  store volatile i8 %r82, ptr %r81
  %r83 = load i64, i64* %ptr_ip
  %r84 = add i64 %r83, 3
  %r85 = inttoptr i64 %r84 to ptr
  %r86 = trunc i64 40 to i8
  store volatile i8 %r86, ptr %r85
  %r87 = load i64, i64* %ptr_ip
  %r88 = add i64 %r87, 4
  %r89 = inttoptr i64 %r88 to ptr
  %r90 = trunc i64 17 to i8
  store volatile i8 %r90, ptr %r89
  %r91 = load i64, i64* %ptr_ip
  %r92 = add i64 %r91, 5
  %r93 = inttoptr i64 %r92 to ptr
  %r94 = trunc i64 18 to i8
  store volatile i8 %r94, ptr %r93
  %r95 = load i64, i64* %ptr_ip
  %r96 = add i64 %r95, 6
  %r97 = inttoptr i64 %r96 to ptr
  %r98 = trunc i64 64 to i8
  store volatile i8 %r98, ptr %r97
  %r99 = load i64, i64* %ptr_ip
  %r100 = add i64 %r99, 7
  %r101 = inttoptr i64 %r100 to ptr
  %r102 = trunc i64 0 to i8
  store volatile i8 %r102, ptr %r101
  %r103 = load i64, i64* %ptr_ip
  %r104 = add i64 %r103, 8
  %r105 = inttoptr i64 %r104 to ptr
  %r106 = trunc i64 64 to i8
  store volatile i8 %r106, ptr %r105
  %r107 = load i64, i64* %ptr_ip
  %r108 = add i64 %r107, 9
  %r109 = inttoptr i64 %r108 to ptr
  %r110 = trunc i64 6 to i8
  store volatile i8 %r110, ptr %r109
  %r111 = load i64, i64* %ptr_ip
  %r112 = add i64 %r111, 10
  %r113 = inttoptr i64 %r112 to ptr
  %r114 = trunc i64 0 to i8
  store volatile i8 %r114, ptr %r113
  %r115 = load i64, i64* %ptr_ip
  %r116 = add i64 %r115, 11
  %r117 = inttoptr i64 %r116 to ptr
  %r118 = trunc i64 0 to i8
  store volatile i8 %r118, ptr %r117
  %r119 = load i64, i64* %ptr_ip
  %r120 = add i64 %r119, 12
  %r121 = inttoptr i64 %r120 to ptr
  %r122 = trunc i64 10 to i8
  store volatile i8 %r122, ptr %r121
  %r123 = load i64, i64* %ptr_ip
  %r124 = add i64 %r123, 13
  %r125 = inttoptr i64 %r124 to ptr
  %r126 = trunc i64 0 to i8
  store volatile i8 %r126, ptr %r125
  %r127 = load i64, i64* %ptr_ip
  %r128 = add i64 %r127, 14
  %r129 = inttoptr i64 %r128 to ptr
  %r130 = trunc i64 2 to i8
  store volatile i8 %r130, ptr %r129
  %r131 = load i64, i64* %ptr_ip
  %r132 = add i64 %r131, 15
  %r133 = inttoptr i64 %r132 to ptr
  %r134 = trunc i64 15 to i8
  store volatile i8 %r134, ptr %r133
  %r135 = load i64, i64* %ptr_ip
  %r136 = add i64 %r135, 16
  %r137 = inttoptr i64 %r136 to ptr
  %r138 = trunc i64 1 to i8
  store volatile i8 %r138, ptr %r137
  %r139 = load i64, i64* %ptr_ip
  %r140 = add i64 %r139, 17
  %r141 = inttoptr i64 %r140 to ptr
  %r142 = trunc i64 1 to i8
  store volatile i8 %r142, ptr %r141
  %r143 = load i64, i64* %ptr_ip
  %r144 = add i64 %r143, 18
  %r145 = inttoptr i64 %r144 to ptr
  %r146 = trunc i64 1 to i8
  store volatile i8 %r146, ptr %r145
  %r147 = load i64, i64* %ptr_ip
  %r148 = add i64 %r147, 19
  %r149 = inttoptr i64 %r148 to ptr
  %r150 = trunc i64 1 to i8
  store volatile i8 %r150, ptr %r149
  %r151 = load i64, i64* %ptr_f
  %r152 = add i64 %r151, 34
  store i64 %r152, i64* %ptr_tcp
  %r153 = load i64, i64* %ptr_tcp
  %r154 = add i64 %r153, 0
  %r155 = load i64, i64* %ptr_src_port
  %r156 = lshr i64 %r155, 8
  %r157 = and i64 %r156, 255
  %r158 = inttoptr i64 %r154 to ptr
  %r159 = trunc i64 %r157 to i8
  store volatile i8 %r159, ptr %r158
  %r160 = load i64, i64* %ptr_tcp
  %r161 = add i64 %r160, 1
  %r162 = load i64, i64* %ptr_src_port
  %r163 = and i64 %r162, 255
  %r164 = inttoptr i64 %r161 to ptr
  %r165 = trunc i64 %r163 to i8
  store volatile i8 %r165, ptr %r164
  %r166 = load i64, i64* %ptr_tcp
  %r167 = add i64 %r166, 2
  %r168 = inttoptr i64 %r167 to ptr
  %r169 = trunc i64 0 to i8
  store volatile i8 %r169, ptr %r168
  %r170 = load i64, i64* %ptr_tcp
  %r171 = add i64 %r170, 3
  %r172 = inttoptr i64 %r171 to ptr
  %r173 = trunc i64 80 to i8
  store volatile i8 %r173, ptr %r172
  %r174 = load i64, i64* %ptr_tcp
  %r175 = add i64 %r174, 4
  %r176 = load i64, i64* %ptr_seq
  %r177 = lshr i64 %r176, 24
  %r178 = and i64 %r177, 255
  %r179 = inttoptr i64 %r175 to ptr
  %r180 = trunc i64 %r178 to i8
  store volatile i8 %r180, ptr %r179
  %r181 = load i64, i64* %ptr_tcp
  %r182 = add i64 %r181, 5
  %r183 = load i64, i64* %ptr_seq
  %r184 = lshr i64 %r183, 16
  %r185 = and i64 %r184, 255
  %r186 = inttoptr i64 %r182 to ptr
  %r187 = trunc i64 %r185 to i8
  store volatile i8 %r187, ptr %r186
  %r188 = load i64, i64* %ptr_tcp
  %r189 = add i64 %r188, 6
  %r190 = load i64, i64* %ptr_seq
  %r191 = lshr i64 %r190, 8
  %r192 = and i64 %r191, 255
  %r193 = inttoptr i64 %r189 to ptr
  %r194 = trunc i64 %r192 to i8
  store volatile i8 %r194, ptr %r193
  %r195 = load i64, i64* %ptr_tcp
  %r196 = add i64 %r195, 7
  %r197 = load i64, i64* %ptr_seq
  %r198 = and i64 %r197, 255
  %r199 = inttoptr i64 %r196 to ptr
  %r200 = trunc i64 %r198 to i8
  store volatile i8 %r200, ptr %r199
  %r201 = load i64, i64* %ptr_tcp
  %r202 = add i64 %r201, 8
  %r203 = load i64, i64* %ptr_a1
  %r204 = inttoptr i64 %r202 to ptr
  %r205 = trunc i64 %r203 to i8
  store volatile i8 %r205, ptr %r204
  %r206 = load i64, i64* %ptr_tcp
  %r207 = add i64 %r206, 9
  %r208 = load i64, i64* %ptr_a2
  %r209 = inttoptr i64 %r207 to ptr
  %r210 = trunc i64 %r208 to i8
  store volatile i8 %r210, ptr %r209
  %r211 = load i64, i64* %ptr_tcp
  %r212 = add i64 %r211, 10
  %r213 = load i64, i64* %ptr_a3
  %r214 = inttoptr i64 %r212 to ptr
  %r215 = trunc i64 %r213 to i8
  store volatile i8 %r215, ptr %r214
  %r216 = load i64, i64* %ptr_tcp
  %r217 = add i64 %r216, 11
  %r218 = load i64, i64* %ptr_a4
  %r219 = inttoptr i64 %r217 to ptr
  %r220 = trunc i64 %r218 to i8
  store volatile i8 %r220, ptr %r219
  %r221 = load i64, i64* %ptr_tcp
  %r222 = add i64 %r221, 12
  %r223 = inttoptr i64 %r222 to ptr
  %r224 = trunc i64 80 to i8
  store volatile i8 %r224, ptr %r223
  %r225 = load i64, i64* %ptr_tcp
  %r226 = add i64 %r225, 13
  %r227 = inttoptr i64 %r226 to ptr
  %r228 = trunc i64 16 to i8
  store volatile i8 %r228, ptr %r227
  %r229 = load i64, i64* %ptr_tcp
  %r230 = add i64 %r229, 14
  %r231 = inttoptr i64 %r230 to ptr
  %r232 = trunc i64 255 to i8
  store volatile i8 %r232, ptr %r231
  %r233 = load i64, i64* %ptr_tcp
  %r234 = add i64 %r233, 15
  %r235 = inttoptr i64 %r234 to ptr
  %r236 = trunc i64 255 to i8
  store volatile i8 %r236, ptr %r235
  %r237 = load i64, i64* %ptr_tcp
  %r238 = add i64 %r237, 16
  %r239 = inttoptr i64 %r238 to ptr
  %r240 = trunc i64 0 to i8
  store volatile i8 %r240, ptr %r239
  %r241 = load i64, i64* %ptr_tcp
  %r242 = add i64 %r241, 17
  %r243 = inttoptr i64 %r242 to ptr
  %r244 = trunc i64 0 to i8
  store volatile i8 %r244, ptr %r243
  %r245 = load i64, i64* %ptr_tcp
  %r246 = add i64 %r245, 18
  %r247 = inttoptr i64 %r246 to ptr
  %r248 = trunc i64 0 to i8
  store volatile i8 %r248, ptr %r247
  %r249 = load i64, i64* %ptr_tcp
  %r250 = add i64 %r249, 19
  %r251 = inttoptr i64 %r250 to ptr
  %r252 = trunc i64 0 to i8
  store volatile i8 %r252, ptr %r251
  call void asm sideeffect "mfence", "~{memory}"()
  %r253 = load i64, i64* %ptr_ip
  %r254 = call i64 @net_checksum(i64 %r253, i64 20)
  store i64 %r254, i64* %ptr_ip_csum
  %r255 = load i64, i64* %ptr_ip
  %r256 = add i64 %r255, 10
  %r257 = load i64, i64* %ptr_ip_csum
  %r258 = lshr i64 %r257, 8
  %r259 = and i64 %r258, 255
  %r260 = inttoptr i64 %r256 to ptr
  %r261 = trunc i64 %r259 to i8
  store volatile i8 %r261, ptr %r260
  %r262 = load i64, i64* %ptr_ip
  %r263 = add i64 %r262, 11
  %r264 = load i64, i64* %ptr_ip_csum
  %r265 = and i64 %r264, 255
  %r266 = inttoptr i64 %r263 to ptr
  %r267 = trunc i64 %r265 to i8
  store volatile i8 %r267, ptr %r266
  %r268 = call i64 @malloc(i64 64)
  store i64 %r268, i64* %ptr_pseudo
  %r269 = load i64, i64* %ptr_pseudo
  %r270 = add i64 %r269, 0
  %r271 = inttoptr i64 %r270 to ptr
  %r272 = trunc i64 10 to i8
  store volatile i8 %r272, ptr %r271
  %r273 = load i64, i64* %ptr_pseudo
  %r274 = add i64 %r273, 1
  %r275 = inttoptr i64 %r274 to ptr
  %r276 = trunc i64 0 to i8
  store volatile i8 %r276, ptr %r275
  %r277 = load i64, i64* %ptr_pseudo
  %r278 = add i64 %r277, 2
  %r279 = inttoptr i64 %r278 to ptr
  %r280 = trunc i64 2 to i8
  store volatile i8 %r280, ptr %r279
  %r281 = load i64, i64* %ptr_pseudo
  %r282 = add i64 %r281, 3
  %r283 = inttoptr i64 %r282 to ptr
  %r284 = trunc i64 15 to i8
  store volatile i8 %r284, ptr %r283
  %r285 = load i64, i64* %ptr_pseudo
  %r286 = add i64 %r285, 4
  %r287 = inttoptr i64 %r286 to ptr
  %r288 = trunc i64 1 to i8
  store volatile i8 %r288, ptr %r287
  %r289 = load i64, i64* %ptr_pseudo
  %r290 = add i64 %r289, 5
  %r291 = inttoptr i64 %r290 to ptr
  %r292 = trunc i64 1 to i8
  store volatile i8 %r292, ptr %r291
  %r293 = load i64, i64* %ptr_pseudo
  %r294 = add i64 %r293, 6
  %r295 = inttoptr i64 %r294 to ptr
  %r296 = trunc i64 1 to i8
  store volatile i8 %r296, ptr %r295
  %r297 = load i64, i64* %ptr_pseudo
  %r298 = add i64 %r297, 7
  %r299 = inttoptr i64 %r298 to ptr
  %r300 = trunc i64 1 to i8
  store volatile i8 %r300, ptr %r299
  %r301 = load i64, i64* %ptr_pseudo
  %r302 = add i64 %r301, 8
  %r303 = inttoptr i64 %r302 to ptr
  %r304 = trunc i64 0 to i8
  store volatile i8 %r304, ptr %r303
  %r305 = load i64, i64* %ptr_pseudo
  %r306 = add i64 %r305, 9
  %r307 = inttoptr i64 %r306 to ptr
  %r308 = trunc i64 6 to i8
  store volatile i8 %r308, ptr %r307
  %r309 = load i64, i64* %ptr_pseudo
  %r310 = add i64 %r309, 10
  %r311 = inttoptr i64 %r310 to ptr
  %r312 = trunc i64 0 to i8
  store volatile i8 %r312, ptr %r311
  %r313 = load i64, i64* %ptr_pseudo
  %r314 = add i64 %r313, 11
  %r315 = inttoptr i64 %r314 to ptr
  %r316 = trunc i64 20 to i8
  store volatile i8 %r316, ptr %r315
  store i64 0, i64* %ptr_c_i
  br label %L259
L259:
  %r317 = load i64, i64* %ptr_c_i
  %r319 = icmp slt i64 %r317, 20
  %r318 = zext i1 %r319 to i64
  %r320 = icmp ne i64 %r318, 0
  br i1 %r320, label %L260, label %L261
L260:
  %r321 = load i64, i64* %ptr_pseudo
  %r322 = load i64, i64* %ptr_c_i
  %r323 = call i64 @_add(i64 12, i64 %r322)
  %r324 = add i64 %r321, %r323
  %r325 = load i64, i64* %ptr_tcp
  %r326 = load i64, i64* %ptr_c_i
  %r327 = add i64 %r325, %r326
  %r328 = inttoptr i64 %r327 to ptr
  %r329 = load volatile i8, ptr %r328
  %r330 = zext i8 %r329 to i64
  %r331 = inttoptr i64 %r324 to ptr
  %r332 = trunc i64 %r330 to i8
  store volatile i8 %r332, ptr %r331
  %r333 = load i64, i64* %ptr_c_i
  %r334 = call i64 @_add(i64 %r333, i64 1)
  store i64 %r334, i64* %ptr_c_i
  br label %L259
L261:
  call void asm sideeffect "mfence", "~{memory}"()
  %r335 = load i64, i64* %ptr_pseudo
  %r336 = call i64 @net_checksum(i64 %r335, i64 32)
  store i64 %r336, i64* %ptr_tcp_csum
  %r337 = load i64, i64* %ptr_tcp
  %r338 = add i64 %r337, 16
  %r339 = load i64, i64* %ptr_tcp_csum
  %r340 = lshr i64 %r339, 8
  %r341 = and i64 %r340, 255
  %r342 = inttoptr i64 %r338 to ptr
  %r343 = trunc i64 %r341 to i8
  store volatile i8 %r343, ptr %r342
  %r344 = load i64, i64* %ptr_tcp
  %r345 = add i64 %r344, 17
  %r346 = load i64, i64* %ptr_tcp_csum
  %r347 = and i64 %r346, 255
  %r348 = inttoptr i64 %r345 to ptr
  %r349 = trunc i64 %r347 to i8
  store volatile i8 %r349, ptr %r348
  call void asm sideeffect "mfence", "~{memory}"()
  %r350 = load i64, i64* %ptr_f
  %r351 = call i64 @e1000_transmit(i64 %r350, i64 64)
  store i64 100000, i64* %ptr_timeout
  br label %L262
L262:
  %r352 = load i64, i64* %ptr_timeout
  %r354 = icmp sgt i64 %r352, 0
  %r353 = zext i1 %r354 to i64
  %r355 = icmp ne i64 %r353, 0
  br i1 %r355, label %L263, label %L264
L263:
  %r356 = load i64, i64* @E1000_BAR
  %r357 = add i64 %r356, 14352
  %r358 = inttoptr i64 %r357 to i32*
  %r359 = load volatile i32, i32* %r358
  %r360 = zext i32 %r359 to i64
  %r361 = load i64, i64* @E1000_TX_TAIL
  %r362 = call i64 @_eq(i64 %r360, i64 %r361)
  %r363 = icmp ne i64 %r362, 0
  br i1 %r363, label %L265, label %L267
L265:
  store i64 0, i64* %ptr_timeout
  br label %L267
L267:
  %r364 = load i64, i64* %ptr_timeout
  %r365 = sub i64 %r364, 1
  store i64 %r365, i64* %ptr_timeout
  br label %L262
L264:
  ret i64 0
}
define i64 @e1000_send_get(i64 %arg_src_port, i64 %arg_seq, i64 %arg_a1, i64 %arg_a2, i64 %arg_a3, i64 %arg_a4) {
  %ptr_src_port = alloca i64
  store i64 %arg_src_port, i64* %ptr_src_port
  %ptr_seq = alloca i64
  store i64 %arg_seq, i64* %ptr_seq
  %ptr_a1 = alloca i64
  store i64 %arg_a1, i64* %ptr_a1
  %ptr_a2 = alloca i64
  store i64 %arg_a2, i64* %ptr_a2
  %ptr_a3 = alloca i64
  store i64 %arg_a3, i64* %ptr_a3
  %ptr_a4 = alloca i64
  store i64 %arg_a4, i64* %ptr_a4
  %ptr_f = alloca i64
  %ptr_z = alloca i64
  %ptr_payload_len = alloca i64
  %ptr_ip = alloca i64
  %ptr_tlen = alloca i64
  %ptr_tcp = alloca i64
  %ptr_p = alloca i64
  %ptr_ip_csum = alloca i64
  %ptr_pseudo = alloca i64
  %ptr_c_i = alloca i64
  %ptr_tcp_csum = alloca i64
  %ptr_timeout = alloca i64
  %r1 = call i64 @malloc(i64 110)
  store i64 %r1, i64* %ptr_f
  store i64 0, i64* %ptr_z
  br label %L268
L268:
  %r2 = load i64, i64* %ptr_z
  %r4 = icmp slt i64 %r2, 110
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L269, label %L270
L269:
  %r6 = load i64, i64* %ptr_f
  %r7 = load i64, i64* %ptr_z
  %r8 = add i64 %r6, %r7
  %r9 = inttoptr i64 %r8 to ptr
  %r10 = trunc i64 0 to i8
  store volatile i8 %r10, ptr %r9
  %r11 = load i64, i64* %ptr_z
  %r12 = call i64 @_add(i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_z
  br label %L268
L270:
  store i64 52, i64* %ptr_payload_len
  %r13 = load i64, i64* %ptr_f
  %r14 = add i64 %r13, 0
  %r15 = inttoptr i64 %r14 to ptr
  %r16 = trunc i64 82 to i8
  store volatile i8 %r16, ptr %r15
  %r17 = load i64, i64* %ptr_f
  %r18 = add i64 %r17, 1
  %r19 = inttoptr i64 %r18 to ptr
  %r20 = trunc i64 85 to i8
  store volatile i8 %r20, ptr %r19
  %r21 = load i64, i64* %ptr_f
  %r22 = add i64 %r21, 2
  %r23 = inttoptr i64 %r22 to ptr
  %r24 = trunc i64 10 to i8
  store volatile i8 %r24, ptr %r23
  %r25 = load i64, i64* %ptr_f
  %r26 = add i64 %r25, 3
  %r27 = inttoptr i64 %r26 to ptr
  %r28 = trunc i64 0 to i8
  store volatile i8 %r28, ptr %r27
  %r29 = load i64, i64* %ptr_f
  %r30 = add i64 %r29, 4
  %r31 = inttoptr i64 %r30 to ptr
  %r32 = trunc i64 2 to i8
  store volatile i8 %r32, ptr %r31
  %r33 = load i64, i64* %ptr_f
  %r34 = add i64 %r33, 5
  %r35 = inttoptr i64 %r34 to ptr
  %r36 = trunc i64 2 to i8
  store volatile i8 %r36, ptr %r35
  %r37 = load i64, i64* %ptr_f
  %r38 = add i64 %r37, 6
  %r39 = inttoptr i64 %r38 to ptr
  %r40 = trunc i64 82 to i8
  store volatile i8 %r40, ptr %r39
  %r41 = load i64, i64* %ptr_f
  %r42 = add i64 %r41, 7
  %r43 = inttoptr i64 %r42 to ptr
  %r44 = trunc i64 84 to i8
  store volatile i8 %r44, ptr %r43
  %r45 = load i64, i64* %ptr_f
  %r46 = add i64 %r45, 8
  %r47 = inttoptr i64 %r46 to ptr
  %r48 = trunc i64 0 to i8
  store volatile i8 %r48, ptr %r47
  %r49 = load i64, i64* %ptr_f
  %r50 = add i64 %r49, 9
  %r51 = inttoptr i64 %r50 to ptr
  %r52 = trunc i64 18 to i8
  store volatile i8 %r52, ptr %r51
  %r53 = load i64, i64* %ptr_f
  %r54 = add i64 %r53, 10
  %r55 = inttoptr i64 %r54 to ptr
  %r56 = trunc i64 52 to i8
  store volatile i8 %r56, ptr %r55
  %r57 = load i64, i64* %ptr_f
  %r58 = add i64 %r57, 11
  %r59 = inttoptr i64 %r58 to ptr
  %r60 = trunc i64 86 to i8
  store volatile i8 %r60, ptr %r59
  %r61 = load i64, i64* %ptr_f
  %r62 = add i64 %r61, 12
  %r63 = inttoptr i64 %r62 to ptr
  %r64 = trunc i64 8 to i8
  store volatile i8 %r64, ptr %r63
  %r65 = load i64, i64* %ptr_f
  %r66 = add i64 %r65, 13
  %r67 = inttoptr i64 %r66 to ptr
  %r68 = trunc i64 0 to i8
  store volatile i8 %r68, ptr %r67
  %r69 = load i64, i64* %ptr_f
  %r70 = add i64 %r69, 14
  store i64 %r70, i64* %ptr_ip
  %r71 = load i64, i64* %ptr_payload_len
  %r72 = call i64 @_add(i64 40, i64 %r71)
  store i64 %r72, i64* %ptr_tlen
  %r73 = load i64, i64* %ptr_ip
  %r74 = add i64 %r73, 0
  %r75 = inttoptr i64 %r74 to ptr
  %r76 = trunc i64 69 to i8
  store volatile i8 %r76, ptr %r75
  %r77 = load i64, i64* %ptr_ip
  %r78 = add i64 %r77, 1
  %r79 = inttoptr i64 %r78 to ptr
  %r80 = trunc i64 0 to i8
  store volatile i8 %r80, ptr %r79
  %r81 = load i64, i64* %ptr_ip
  %r82 = add i64 %r81, 2
  %r83 = load i64, i64* %ptr_tlen
  %r84 = lshr i64 %r83, 8
  %r85 = and i64 %r84, 255
  %r86 = inttoptr i64 %r82 to ptr
  %r87 = trunc i64 %r85 to i8
  store volatile i8 %r87, ptr %r86
  %r88 = load i64, i64* %ptr_ip
  %r89 = add i64 %r88, 3
  %r90 = load i64, i64* %ptr_tlen
  %r91 = and i64 %r90, 255
  %r92 = inttoptr i64 %r89 to ptr
  %r93 = trunc i64 %r91 to i8
  store volatile i8 %r93, ptr %r92
  %r94 = load i64, i64* %ptr_ip
  %r95 = add i64 %r94, 4
  %r96 = inttoptr i64 %r95 to ptr
  %r97 = trunc i64 17 to i8
  store volatile i8 %r97, ptr %r96
  %r98 = load i64, i64* %ptr_ip
  %r99 = add i64 %r98, 5
  %r100 = inttoptr i64 %r99 to ptr
  %r101 = trunc i64 19 to i8
  store volatile i8 %r101, ptr %r100
  %r102 = load i64, i64* %ptr_ip
  %r103 = add i64 %r102, 6
  %r104 = inttoptr i64 %r103 to ptr
  %r105 = trunc i64 64 to i8
  store volatile i8 %r105, ptr %r104
  %r106 = load i64, i64* %ptr_ip
  %r107 = add i64 %r106, 7
  %r108 = inttoptr i64 %r107 to ptr
  %r109 = trunc i64 0 to i8
  store volatile i8 %r109, ptr %r108
  %r110 = load i64, i64* %ptr_ip
  %r111 = add i64 %r110, 8
  %r112 = inttoptr i64 %r111 to ptr
  %r113 = trunc i64 64 to i8
  store volatile i8 %r113, ptr %r112
  %r114 = load i64, i64* %ptr_ip
  %r115 = add i64 %r114, 9
  %r116 = inttoptr i64 %r115 to ptr
  %r117 = trunc i64 6 to i8
  store volatile i8 %r117, ptr %r116
  %r118 = load i64, i64* %ptr_ip
  %r119 = add i64 %r118, 10
  %r120 = inttoptr i64 %r119 to ptr
  %r121 = trunc i64 0 to i8
  store volatile i8 %r121, ptr %r120
  %r122 = load i64, i64* %ptr_ip
  %r123 = add i64 %r122, 11
  %r124 = inttoptr i64 %r123 to ptr
  %r125 = trunc i64 0 to i8
  store volatile i8 %r125, ptr %r124
  %r126 = load i64, i64* %ptr_ip
  %r127 = add i64 %r126, 12
  %r128 = inttoptr i64 %r127 to ptr
  %r129 = trunc i64 10 to i8
  store volatile i8 %r129, ptr %r128
  %r130 = load i64, i64* %ptr_ip
  %r131 = add i64 %r130, 13
  %r132 = inttoptr i64 %r131 to ptr
  %r133 = trunc i64 0 to i8
  store volatile i8 %r133, ptr %r132
  %r134 = load i64, i64* %ptr_ip
  %r135 = add i64 %r134, 14
  %r136 = inttoptr i64 %r135 to ptr
  %r137 = trunc i64 2 to i8
  store volatile i8 %r137, ptr %r136
  %r138 = load i64, i64* %ptr_ip
  %r139 = add i64 %r138, 15
  %r140 = inttoptr i64 %r139 to ptr
  %r141 = trunc i64 15 to i8
  store volatile i8 %r141, ptr %r140
  %r142 = load i64, i64* %ptr_ip
  %r143 = add i64 %r142, 16
  %r144 = inttoptr i64 %r143 to ptr
  %r145 = trunc i64 1 to i8
  store volatile i8 %r145, ptr %r144
  %r146 = load i64, i64* %ptr_ip
  %r147 = add i64 %r146, 17
  %r148 = inttoptr i64 %r147 to ptr
  %r149 = trunc i64 1 to i8
  store volatile i8 %r149, ptr %r148
  %r150 = load i64, i64* %ptr_ip
  %r151 = add i64 %r150, 18
  %r152 = inttoptr i64 %r151 to ptr
  %r153 = trunc i64 1 to i8
  store volatile i8 %r153, ptr %r152
  %r154 = load i64, i64* %ptr_ip
  %r155 = add i64 %r154, 19
  %r156 = inttoptr i64 %r155 to ptr
  %r157 = trunc i64 1 to i8
  store volatile i8 %r157, ptr %r156
  %r158 = load i64, i64* %ptr_f
  %r159 = add i64 %r158, 34
  store i64 %r159, i64* %ptr_tcp
  %r160 = load i64, i64* %ptr_tcp
  %r161 = add i64 %r160, 0
  %r162 = load i64, i64* %ptr_src_port
  %r163 = lshr i64 %r162, 8
  %r164 = and i64 %r163, 255
  %r165 = inttoptr i64 %r161 to ptr
  %r166 = trunc i64 %r164 to i8
  store volatile i8 %r166, ptr %r165
  %r167 = load i64, i64* %ptr_tcp
  %r168 = add i64 %r167, 1
  %r169 = load i64, i64* %ptr_src_port
  %r170 = and i64 %r169, 255
  %r171 = inttoptr i64 %r168 to ptr
  %r172 = trunc i64 %r170 to i8
  store volatile i8 %r172, ptr %r171
  %r173 = load i64, i64* %ptr_tcp
  %r174 = add i64 %r173, 2
  %r175 = inttoptr i64 %r174 to ptr
  %r176 = trunc i64 0 to i8
  store volatile i8 %r176, ptr %r175
  %r177 = load i64, i64* %ptr_tcp
  %r178 = add i64 %r177, 3
  %r179 = inttoptr i64 %r178 to ptr
  %r180 = trunc i64 80 to i8
  store volatile i8 %r180, ptr %r179
  %r181 = load i64, i64* %ptr_tcp
  %r182 = add i64 %r181, 4
  %r183 = load i64, i64* %ptr_seq
  %r184 = lshr i64 %r183, 24
  %r185 = and i64 %r184, 255
  %r186 = inttoptr i64 %r182 to ptr
  %r187 = trunc i64 %r185 to i8
  store volatile i8 %r187, ptr %r186
  %r188 = load i64, i64* %ptr_tcp
  %r189 = add i64 %r188, 5
  %r190 = load i64, i64* %ptr_seq
  %r191 = lshr i64 %r190, 16
  %r192 = and i64 %r191, 255
  %r193 = inttoptr i64 %r189 to ptr
  %r194 = trunc i64 %r192 to i8
  store volatile i8 %r194, ptr %r193
  %r195 = load i64, i64* %ptr_tcp
  %r196 = add i64 %r195, 6
  %r197 = load i64, i64* %ptr_seq
  %r198 = lshr i64 %r197, 8
  %r199 = and i64 %r198, 255
  %r200 = inttoptr i64 %r196 to ptr
  %r201 = trunc i64 %r199 to i8
  store volatile i8 %r201, ptr %r200
  %r202 = load i64, i64* %ptr_tcp
  %r203 = add i64 %r202, 7
  %r204 = load i64, i64* %ptr_seq
  %r205 = and i64 %r204, 255
  %r206 = inttoptr i64 %r203 to ptr
  %r207 = trunc i64 %r205 to i8
  store volatile i8 %r207, ptr %r206
  %r208 = load i64, i64* %ptr_tcp
  %r209 = add i64 %r208, 8
  %r210 = load i64, i64* %ptr_a1
  %r211 = inttoptr i64 %r209 to ptr
  %r212 = trunc i64 %r210 to i8
  store volatile i8 %r212, ptr %r211
  %r213 = load i64, i64* %ptr_tcp
  %r214 = add i64 %r213, 9
  %r215 = load i64, i64* %ptr_a2
  %r216 = inttoptr i64 %r214 to ptr
  %r217 = trunc i64 %r215 to i8
  store volatile i8 %r217, ptr %r216
  %r218 = load i64, i64* %ptr_tcp
  %r219 = add i64 %r218, 10
  %r220 = load i64, i64* %ptr_a3
  %r221 = inttoptr i64 %r219 to ptr
  %r222 = trunc i64 %r220 to i8
  store volatile i8 %r222, ptr %r221
  %r223 = load i64, i64* %ptr_tcp
  %r224 = add i64 %r223, 11
  %r225 = load i64, i64* %ptr_a4
  %r226 = inttoptr i64 %r224 to ptr
  %r227 = trunc i64 %r225 to i8
  store volatile i8 %r227, ptr %r226
  %r228 = load i64, i64* %ptr_tcp
  %r229 = add i64 %r228, 12
  %r230 = inttoptr i64 %r229 to ptr
  %r231 = trunc i64 80 to i8
  store volatile i8 %r231, ptr %r230
  %r232 = load i64, i64* %ptr_tcp
  %r233 = add i64 %r232, 13
  %r234 = inttoptr i64 %r233 to ptr
  %r235 = trunc i64 24 to i8
  store volatile i8 %r235, ptr %r234
  %r236 = load i64, i64* %ptr_tcp
  %r237 = add i64 %r236, 14
  %r238 = inttoptr i64 %r237 to ptr
  %r239 = trunc i64 255 to i8
  store volatile i8 %r239, ptr %r238
  %r240 = load i64, i64* %ptr_tcp
  %r241 = add i64 %r240, 15
  %r242 = inttoptr i64 %r241 to ptr
  %r243 = trunc i64 255 to i8
  store volatile i8 %r243, ptr %r242
  %r244 = load i64, i64* %ptr_tcp
  %r245 = add i64 %r244, 16
  %r246 = inttoptr i64 %r245 to ptr
  %r247 = trunc i64 0 to i8
  store volatile i8 %r247, ptr %r246
  %r248 = load i64, i64* %ptr_tcp
  %r249 = add i64 %r248, 17
  %r250 = inttoptr i64 %r249 to ptr
  %r251 = trunc i64 0 to i8
  store volatile i8 %r251, ptr %r250
  %r252 = load i64, i64* %ptr_tcp
  %r253 = add i64 %r252, 18
  %r254 = inttoptr i64 %r253 to ptr
  %r255 = trunc i64 0 to i8
  store volatile i8 %r255, ptr %r254
  %r256 = load i64, i64* %ptr_tcp
  %r257 = add i64 %r256, 19
  %r258 = inttoptr i64 %r257 to ptr
  %r259 = trunc i64 0 to i8
  store volatile i8 %r259, ptr %r258
  %r260 = load i64, i64* %ptr_f
  %r261 = add i64 %r260, 54
  store i64 %r261, i64* %ptr_p
  %r262 = load i64, i64* %ptr_p
  %r263 = add i64 %r262, 0
  %r264 = inttoptr i64 %r263 to ptr
  %r265 = trunc i64 71 to i8
  store volatile i8 %r265, ptr %r264
  %r266 = load i64, i64* %ptr_p
  %r267 = add i64 %r266, 1
  %r268 = inttoptr i64 %r267 to ptr
  %r269 = trunc i64 69 to i8
  store volatile i8 %r269, ptr %r268
  %r270 = load i64, i64* %ptr_p
  %r271 = add i64 %r270, 2
  %r272 = inttoptr i64 %r271 to ptr
  %r273 = trunc i64 84 to i8
  store volatile i8 %r273, ptr %r272
  %r274 = load i64, i64* %ptr_p
  %r275 = add i64 %r274, 3
  %r276 = inttoptr i64 %r275 to ptr
  %r277 = trunc i64 32 to i8
  store volatile i8 %r277, ptr %r276
  %r278 = load i64, i64* %ptr_p
  %r279 = add i64 %r278, 4
  %r280 = inttoptr i64 %r279 to ptr
  %r281 = trunc i64 47 to i8
  store volatile i8 %r281, ptr %r280
  %r282 = load i64, i64* %ptr_p
  %r283 = add i64 %r282, 5
  %r284 = inttoptr i64 %r283 to ptr
  %r285 = trunc i64 32 to i8
  store volatile i8 %r285, ptr %r284
  %r286 = load i64, i64* %ptr_p
  %r287 = add i64 %r286, 6
  %r288 = inttoptr i64 %r287 to ptr
  %r289 = trunc i64 72 to i8
  store volatile i8 %r289, ptr %r288
  %r290 = load i64, i64* %ptr_p
  %r291 = add i64 %r290, 7
  %r292 = inttoptr i64 %r291 to ptr
  %r293 = trunc i64 84 to i8
  store volatile i8 %r293, ptr %r292
  %r294 = load i64, i64* %ptr_p
  %r295 = add i64 %r294, 8
  %r296 = inttoptr i64 %r295 to ptr
  %r297 = trunc i64 84 to i8
  store volatile i8 %r297, ptr %r296
  %r298 = load i64, i64* %ptr_p
  %r299 = add i64 %r298, 9
  %r300 = inttoptr i64 %r299 to ptr
  %r301 = trunc i64 80 to i8
  store volatile i8 %r301, ptr %r300
  %r302 = load i64, i64* %ptr_p
  %r303 = add i64 %r302, 10
  %r304 = inttoptr i64 %r303 to ptr
  %r305 = trunc i64 47 to i8
  store volatile i8 %r305, ptr %r304
  %r306 = load i64, i64* %ptr_p
  %r307 = add i64 %r306, 11
  %r308 = inttoptr i64 %r307 to ptr
  %r309 = trunc i64 49 to i8
  store volatile i8 %r309, ptr %r308
  %r310 = load i64, i64* %ptr_p
  %r311 = add i64 %r310, 12
  %r312 = inttoptr i64 %r311 to ptr
  %r313 = trunc i64 46 to i8
  store volatile i8 %r313, ptr %r312
  %r314 = load i64, i64* %ptr_p
  %r315 = add i64 %r314, 13
  %r316 = inttoptr i64 %r315 to ptr
  %r317 = trunc i64 49 to i8
  store volatile i8 %r317, ptr %r316
  %r318 = load i64, i64* %ptr_p
  %r319 = add i64 %r318, 14
  %r320 = inttoptr i64 %r319 to ptr
  %r321 = trunc i64 13 to i8
  store volatile i8 %r321, ptr %r320
  %r322 = load i64, i64* %ptr_p
  %r323 = add i64 %r322, 15
  %r324 = inttoptr i64 %r323 to ptr
  %r325 = trunc i64 10 to i8
  store volatile i8 %r325, ptr %r324
  %r326 = load i64, i64* %ptr_p
  %r327 = add i64 %r326, 16
  %r328 = inttoptr i64 %r327 to ptr
  %r329 = trunc i64 72 to i8
  store volatile i8 %r329, ptr %r328
  %r330 = load i64, i64* %ptr_p
  %r331 = add i64 %r330, 17
  %r332 = inttoptr i64 %r331 to ptr
  %r333 = trunc i64 111 to i8
  store volatile i8 %r333, ptr %r332
  %r334 = load i64, i64* %ptr_p
  %r335 = add i64 %r334, 18
  %r336 = inttoptr i64 %r335 to ptr
  %r337 = trunc i64 115 to i8
  store volatile i8 %r337, ptr %r336
  %r338 = load i64, i64* %ptr_p
  %r339 = add i64 %r338, 19
  %r340 = inttoptr i64 %r339 to ptr
  %r341 = trunc i64 116 to i8
  store volatile i8 %r341, ptr %r340
  %r342 = load i64, i64* %ptr_p
  %r343 = add i64 %r342, 20
  %r344 = inttoptr i64 %r343 to ptr
  %r345 = trunc i64 58 to i8
  store volatile i8 %r345, ptr %r344
  %r346 = load i64, i64* %ptr_p
  %r347 = add i64 %r346, 21
  %r348 = inttoptr i64 %r347 to ptr
  %r349 = trunc i64 32 to i8
  store volatile i8 %r349, ptr %r348
  %r350 = load i64, i64* %ptr_p
  %r351 = add i64 %r350, 22
  %r352 = inttoptr i64 %r351 to ptr
  %r353 = trunc i64 49 to i8
  store volatile i8 %r353, ptr %r352
  %r354 = load i64, i64* %ptr_p
  %r355 = add i64 %r354, 23
  %r356 = inttoptr i64 %r355 to ptr
  %r357 = trunc i64 46 to i8
  store volatile i8 %r357, ptr %r356
  %r358 = load i64, i64* %ptr_p
  %r359 = add i64 %r358, 24
  %r360 = inttoptr i64 %r359 to ptr
  %r361 = trunc i64 49 to i8
  store volatile i8 %r361, ptr %r360
  %r362 = load i64, i64* %ptr_p
  %r363 = add i64 %r362, 25
  %r364 = inttoptr i64 %r363 to ptr
  %r365 = trunc i64 46 to i8
  store volatile i8 %r365, ptr %r364
  %r366 = load i64, i64* %ptr_p
  %r367 = add i64 %r366, 26
  %r368 = inttoptr i64 %r367 to ptr
  %r369 = trunc i64 49 to i8
  store volatile i8 %r369, ptr %r368
  %r370 = load i64, i64* %ptr_p
  %r371 = add i64 %r370, 27
  %r372 = inttoptr i64 %r371 to ptr
  %r373 = trunc i64 46 to i8
  store volatile i8 %r373, ptr %r372
  %r374 = load i64, i64* %ptr_p
  %r375 = add i64 %r374, 28
  %r376 = inttoptr i64 %r375 to ptr
  %r377 = trunc i64 49 to i8
  store volatile i8 %r377, ptr %r376
  %r378 = load i64, i64* %ptr_p
  %r379 = add i64 %r378, 29
  %r380 = inttoptr i64 %r379 to ptr
  %r381 = trunc i64 13 to i8
  store volatile i8 %r381, ptr %r380
  %r382 = load i64, i64* %ptr_p
  %r383 = add i64 %r382, 30
  %r384 = inttoptr i64 %r383 to ptr
  %r385 = trunc i64 10 to i8
  store volatile i8 %r385, ptr %r384
  %r386 = load i64, i64* %ptr_p
  %r387 = add i64 %r386, 31
  %r388 = inttoptr i64 %r387 to ptr
  %r389 = trunc i64 67 to i8
  store volatile i8 %r389, ptr %r388
  %r390 = load i64, i64* %ptr_p
  %r391 = add i64 %r390, 32
  %r392 = inttoptr i64 %r391 to ptr
  %r393 = trunc i64 111 to i8
  store volatile i8 %r393, ptr %r392
  %r394 = load i64, i64* %ptr_p
  %r395 = add i64 %r394, 33
  %r396 = inttoptr i64 %r395 to ptr
  %r397 = trunc i64 110 to i8
  store volatile i8 %r397, ptr %r396
  %r398 = load i64, i64* %ptr_p
  %r399 = add i64 %r398, 34
  %r400 = inttoptr i64 %r399 to ptr
  %r401 = trunc i64 110 to i8
  store volatile i8 %r401, ptr %r400
  %r402 = load i64, i64* %ptr_p
  %r403 = add i64 %r402, 35
  %r404 = inttoptr i64 %r403 to ptr
  %r405 = trunc i64 101 to i8
  store volatile i8 %r405, ptr %r404
  %r406 = load i64, i64* %ptr_p
  %r407 = add i64 %r406, 36
  %r408 = inttoptr i64 %r407 to ptr
  %r409 = trunc i64 99 to i8
  store volatile i8 %r409, ptr %r408
  %r410 = load i64, i64* %ptr_p
  %r411 = add i64 %r410, 37
  %r412 = inttoptr i64 %r411 to ptr
  %r413 = trunc i64 116 to i8
  store volatile i8 %r413, ptr %r412
  %r414 = load i64, i64* %ptr_p
  %r415 = add i64 %r414, 38
  %r416 = inttoptr i64 %r415 to ptr
  %r417 = trunc i64 105 to i8
  store volatile i8 %r417, ptr %r416
  %r418 = load i64, i64* %ptr_p
  %r419 = add i64 %r418, 39
  %r420 = inttoptr i64 %r419 to ptr
  %r421 = trunc i64 111 to i8
  store volatile i8 %r421, ptr %r420
  %r422 = load i64, i64* %ptr_p
  %r423 = add i64 %r422, 40
  %r424 = inttoptr i64 %r423 to ptr
  %r425 = trunc i64 110 to i8
  store volatile i8 %r425, ptr %r424
  %r426 = load i64, i64* %ptr_p
  %r427 = add i64 %r426, 41
  %r428 = inttoptr i64 %r427 to ptr
  %r429 = trunc i64 58 to i8
  store volatile i8 %r429, ptr %r428
  %r430 = load i64, i64* %ptr_p
  %r431 = add i64 %r430, 42
  %r432 = inttoptr i64 %r431 to ptr
  %r433 = trunc i64 32 to i8
  store volatile i8 %r433, ptr %r432
  %r434 = load i64, i64* %ptr_p
  %r435 = add i64 %r434, 43
  %r436 = inttoptr i64 %r435 to ptr
  %r437 = trunc i64 99 to i8
  store volatile i8 %r437, ptr %r436
  %r438 = load i64, i64* %ptr_p
  %r439 = add i64 %r438, 44
  %r440 = inttoptr i64 %r439 to ptr
  %r441 = trunc i64 108 to i8
  store volatile i8 %r441, ptr %r440
  %r442 = load i64, i64* %ptr_p
  %r443 = add i64 %r442, 45
  %r444 = inttoptr i64 %r443 to ptr
  %r445 = trunc i64 111 to i8
  store volatile i8 %r445, ptr %r444
  %r446 = load i64, i64* %ptr_p
  %r447 = add i64 %r446, 46
  %r448 = inttoptr i64 %r447 to ptr
  %r449 = trunc i64 115 to i8
  store volatile i8 %r449, ptr %r448
  %r450 = load i64, i64* %ptr_p
  %r451 = add i64 %r450, 47
  %r452 = inttoptr i64 %r451 to ptr
  %r453 = trunc i64 101 to i8
  store volatile i8 %r453, ptr %r452
  %r454 = load i64, i64* %ptr_p
  %r455 = add i64 %r454, 48
  %r456 = inttoptr i64 %r455 to ptr
  %r457 = trunc i64 13 to i8
  store volatile i8 %r457, ptr %r456
  %r458 = load i64, i64* %ptr_p
  %r459 = add i64 %r458, 49
  %r460 = inttoptr i64 %r459 to ptr
  %r461 = trunc i64 10 to i8
  store volatile i8 %r461, ptr %r460
  %r462 = load i64, i64* %ptr_p
  %r463 = add i64 %r462, 50
  %r464 = inttoptr i64 %r463 to ptr
  %r465 = trunc i64 13 to i8
  store volatile i8 %r465, ptr %r464
  %r466 = load i64, i64* %ptr_p
  %r467 = add i64 %r466, 51
  %r468 = inttoptr i64 %r467 to ptr
  %r469 = trunc i64 10 to i8
  store volatile i8 %r469, ptr %r468
  call void asm sideeffect "mfence", "~{memory}"()
  %r470 = load i64, i64* %ptr_ip
  %r471 = call i64 @net_checksum(i64 %r470, i64 20)
  store i64 %r471, i64* %ptr_ip_csum
  %r472 = load i64, i64* %ptr_ip
  %r473 = add i64 %r472, 10
  %r474 = load i64, i64* %ptr_ip_csum
  %r475 = lshr i64 %r474, 8
  %r476 = and i64 %r475, 255
  %r477 = inttoptr i64 %r473 to ptr
  %r478 = trunc i64 %r476 to i8
  store volatile i8 %r478, ptr %r477
  %r479 = load i64, i64* %ptr_ip
  %r480 = add i64 %r479, 11
  %r481 = load i64, i64* %ptr_ip_csum
  %r482 = and i64 %r481, 255
  %r483 = inttoptr i64 %r480 to ptr
  %r484 = trunc i64 %r482 to i8
  store volatile i8 %r484, ptr %r483
  %r485 = call i64 @malloc(i64 128)
  store i64 %r485, i64* %ptr_pseudo
  %r486 = load i64, i64* %ptr_pseudo
  %r487 = add i64 %r486, 0
  %r488 = inttoptr i64 %r487 to ptr
  %r489 = trunc i64 10 to i8
  store volatile i8 %r489, ptr %r488
  %r490 = load i64, i64* %ptr_pseudo
  %r491 = add i64 %r490, 1
  %r492 = inttoptr i64 %r491 to ptr
  %r493 = trunc i64 0 to i8
  store volatile i8 %r493, ptr %r492
  %r494 = load i64, i64* %ptr_pseudo
  %r495 = add i64 %r494, 2
  %r496 = inttoptr i64 %r495 to ptr
  %r497 = trunc i64 2 to i8
  store volatile i8 %r497, ptr %r496
  %r498 = load i64, i64* %ptr_pseudo
  %r499 = add i64 %r498, 3
  %r500 = inttoptr i64 %r499 to ptr
  %r501 = trunc i64 15 to i8
  store volatile i8 %r501, ptr %r500
  %r502 = load i64, i64* %ptr_pseudo
  %r503 = add i64 %r502, 4
  %r504 = inttoptr i64 %r503 to ptr
  %r505 = trunc i64 1 to i8
  store volatile i8 %r505, ptr %r504
  %r506 = load i64, i64* %ptr_pseudo
  %r507 = add i64 %r506, 5
  %r508 = inttoptr i64 %r507 to ptr
  %r509 = trunc i64 1 to i8
  store volatile i8 %r509, ptr %r508
  %r510 = load i64, i64* %ptr_pseudo
  %r511 = add i64 %r510, 6
  %r512 = inttoptr i64 %r511 to ptr
  %r513 = trunc i64 1 to i8
  store volatile i8 %r513, ptr %r512
  %r514 = load i64, i64* %ptr_pseudo
  %r515 = add i64 %r514, 7
  %r516 = inttoptr i64 %r515 to ptr
  %r517 = trunc i64 1 to i8
  store volatile i8 %r517, ptr %r516
  %r518 = load i64, i64* %ptr_pseudo
  %r519 = add i64 %r518, 8
  %r520 = inttoptr i64 %r519 to ptr
  %r521 = trunc i64 0 to i8
  store volatile i8 %r521, ptr %r520
  %r522 = load i64, i64* %ptr_pseudo
  %r523 = add i64 %r522, 9
  %r524 = inttoptr i64 %r523 to ptr
  %r525 = trunc i64 6 to i8
  store volatile i8 %r525, ptr %r524
  %r526 = load i64, i64* %ptr_pseudo
  %r527 = add i64 %r526, 10
  %r528 = inttoptr i64 %r527 to ptr
  %r529 = trunc i64 0 to i8
  store volatile i8 %r529, ptr %r528
  %r530 = load i64, i64* %ptr_pseudo
  %r531 = add i64 %r530, 11
  %r532 = inttoptr i64 %r531 to ptr
  %r533 = trunc i64 72 to i8
  store volatile i8 %r533, ptr %r532
  store i64 0, i64* %ptr_c_i
  br label %L271
L271:
  %r534 = load i64, i64* %ptr_c_i
  %r536 = icmp slt i64 %r534, 72
  %r535 = zext i1 %r536 to i64
  %r537 = icmp ne i64 %r535, 0
  br i1 %r537, label %L272, label %L273
L272:
  %r538 = load i64, i64* %ptr_pseudo
  %r539 = load i64, i64* %ptr_c_i
  %r540 = call i64 @_add(i64 12, i64 %r539)
  %r541 = add i64 %r538, %r540
  %r542 = load i64, i64* %ptr_tcp
  %r543 = load i64, i64* %ptr_c_i
  %r544 = add i64 %r542, %r543
  %r545 = inttoptr i64 %r544 to ptr
  %r546 = load volatile i8, ptr %r545
  %r547 = zext i8 %r546 to i64
  %r548 = inttoptr i64 %r541 to ptr
  %r549 = trunc i64 %r547 to i8
  store volatile i8 %r549, ptr %r548
  %r550 = load i64, i64* %ptr_c_i
  %r551 = call i64 @_add(i64 %r550, i64 1)
  store i64 %r551, i64* %ptr_c_i
  br label %L271
L273:
  call void asm sideeffect "mfence", "~{memory}"()
  %r552 = load i64, i64* %ptr_pseudo
  %r553 = call i64 @net_checksum(i64 %r552, i64 84)
  store i64 %r553, i64* %ptr_tcp_csum
  %r554 = load i64, i64* %ptr_tcp
  %r555 = add i64 %r554, 16
  %r556 = load i64, i64* %ptr_tcp_csum
  %r557 = lshr i64 %r556, 8
  %r558 = and i64 %r557, 255
  %r559 = inttoptr i64 %r555 to ptr
  %r560 = trunc i64 %r558 to i8
  store volatile i8 %r560, ptr %r559
  %r561 = load i64, i64* %ptr_tcp
  %r562 = add i64 %r561, 17
  %r563 = load i64, i64* %ptr_tcp_csum
  %r564 = and i64 %r563, 255
  %r565 = inttoptr i64 %r562 to ptr
  %r566 = trunc i64 %r564 to i8
  store volatile i8 %r566, ptr %r565
  call void asm sideeffect "mfence", "~{memory}"()
  %r567 = load i64, i64* %ptr_f
  %r568 = load i64, i64* %ptr_tlen
  %r569 = call i64 @_add(i64 14, i64 %r568)
  %r570 = call i64 @e1000_transmit(i64 %r567, i64 %r569)
  store i64 100000, i64* %ptr_timeout
  br label %L274
L274:
  %r571 = load i64, i64* %ptr_timeout
  %r573 = icmp sgt i64 %r571, 0
  %r572 = zext i1 %r573 to i64
  %r574 = icmp ne i64 %r572, 0
  br i1 %r574, label %L275, label %L276
L275:
  %r575 = load i64, i64* @E1000_BAR
  %r576 = add i64 %r575, 14352
  %r577 = inttoptr i64 %r576 to i32*
  %r578 = load volatile i32, i32* %r577
  %r579 = zext i32 %r578 to i64
  %r580 = load i64, i64* @E1000_TX_TAIL
  %r581 = call i64 @_eq(i64 %r579, i64 %r580)
  %r582 = icmp ne i64 %r581, 0
  br i1 %r582, label %L277, label %L279
L277:
  store i64 0, i64* %ptr_timeout
  br label %L279
L279:
  %r583 = load i64, i64* %ptr_timeout
  %r584 = sub i64 %r583, 1
  store i64 %r584, i64* %ptr_timeout
  br label %L274
L276:
  %r585 = load i64, i64* %ptr_f
  ret i64 %r585
  ret i64 0
}
define i64 @hex_to_dec(i64 %arg_h) {
  %ptr_h = alloca i64
  store i64 %arg_h, i64* %ptr_h
  %ptr_len = alloca i64
  %ptr_val = alloca i64
  %ptr_i = alloca i64
  %ptr_c = alloca i64
  %r1 = load i64, i64* %ptr_h
  %r2 = call i64 @mensura(i64 %r1)
  store i64 %r2, i64* %ptr_len
  store i64 0, i64* %ptr_val
  store i64 0, i64* %ptr_i
  br label %L280
L280:
  %r3 = load i64, i64* %ptr_i
  %r4 = load i64, i64* %ptr_len
  %r6 = icmp slt i64 %r3, %r4
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L281, label %L282
L281:
  %r8 = load i64, i64* %ptr_h
  %r9 = load i64, i64* %ptr_i
  %r10 = call i64 @pars(i64 %r8, i64 %r9, i64 1)
  %r11 = call i64 @codex(i64 %r10)
  store i64 %r11, i64* %ptr_c
  %r12 = load i64, i64* %ptr_val
  %r13 = mul i64 %r12, 16
  store i64 %r13, i64* %ptr_val
  %r14 = load i64, i64* %ptr_c
  %r16 = icmp sge i64 %r14, 48
  %r15 = zext i1 %r16 to i64
  %r17 = icmp ne i64 %r15, 0
  br i1 %r17, label %L283, label %L285
L283:
  %r18 = load i64, i64* %ptr_c
  %r20 = icmp sle i64 %r18, 57
  %r19 = zext i1 %r20 to i64
  %r21 = icmp ne i64 %r19, 0
  br i1 %r21, label %L286, label %L288
L286:
  %r22 = load i64, i64* %ptr_val
  %r23 = load i64, i64* %ptr_c
  %r24 = sub i64 %r23, 48
  %r25 = or i64 %r22, %r24
  store i64 %r25, i64* %ptr_val
  br label %L288
L288:
  br label %L285
L285:
  %r26 = load i64, i64* %ptr_c
  %r28 = icmp sge i64 %r26, 65
  %r27 = zext i1 %r28 to i64
  %r29 = icmp ne i64 %r27, 0
  br i1 %r29, label %L289, label %L291
L289:
  %r30 = load i64, i64* %ptr_c
  %r32 = icmp sle i64 %r30, 70
  %r31 = zext i1 %r32 to i64
  %r33 = icmp ne i64 %r31, 0
  br i1 %r33, label %L292, label %L294
L292:
  %r34 = load i64, i64* %ptr_val
  %r35 = load i64, i64* %ptr_c
  %r36 = sub i64 %r35, 55
  %r37 = or i64 %r34, %r36
  store i64 %r37, i64* %ptr_val
  br label %L294
L294:
  br label %L291
L291:
  %r38 = load i64, i64* %ptr_c
  %r40 = icmp sge i64 %r38, 97
  %r39 = zext i1 %r40 to i64
  %r41 = icmp ne i64 %r39, 0
  br i1 %r41, label %L295, label %L297
L295:
  %r42 = load i64, i64* %ptr_c
  %r44 = icmp sle i64 %r42, 102
  %r43 = zext i1 %r44 to i64
  %r45 = icmp ne i64 %r43, 0
  br i1 %r45, label %L298, label %L300
L298:
  %r46 = load i64, i64* %ptr_val
  %r47 = load i64, i64* %ptr_c
  %r48 = sub i64 %r47, 87
  %r49 = or i64 %r46, %r48
  store i64 %r49, i64* %ptr_val
  br label %L300
L300:
  br label %L297
L297:
  %r50 = load i64, i64* %ptr_i
  %r51 = call i64 @_add(i64 %r50, i64 1)
  store i64 %r51, i64* %ptr_i
  br label %L280
L282:
  %r52 = load i64, i64* %ptr_val
  ret i64 %r52
  ret i64 0
}
define i64 @init_constants() {
  store i64 0, i64* @TOK_EOF
  store i64 1, i64* @TOK_INT
  store i64 2, i64* @TOK_FLOAT
  store i64 3, i64* @TOK_STRING
  store i64 4, i64* @TOK_IDENT
  store i64 5, i64* @TOK_LET
  store i64 6, i64* @TOK_PRINT
  store i64 7, i64* @TOK_IF
  store i64 8, i64* @TOK_ELSE
  store i64 9, i64* @TOK_WHILE
  store i64 10, i64* @TOK_OPUS
  store i64 11, i64* @TOK_REDDO
  store i64 12, i64* @TOK_BREAK
  store i64 13, i64* @TOK_CONTINUE
  store i64 20, i64* @TOK_IMPORT
  store i64 21, i64* @TOK_LPAREN
  store i64 22, i64* @TOK_RPAREN
  store i64 23, i64* @TOK_LBRACE
  store i64 24, i64* @TOK_RBRACE
  store i64 25, i64* @TOK_LBRACKET
  store i64 26, i64* @TOK_RBRACKET
  store i64 27, i64* @TOK_COLON
  store i64 28, i64* @TOK_ARROW
  store i64 29, i64* @TOK_CARET
  store i64 30, i64* @TOK_DOT
  store i64 31, i64* @TOK_APPEND
  store i64 32, i64* @TOK_EXTRACT
  store i64 33, i64* @TOK_AND
  store i64 34, i64* @TOK_OR
  store i64 35, i64* @TOK_CONST
  store i64 36, i64* @TOK_SHARED
  store i64 37, i64* @TOK_OP
  store i64 38, i64* @TOK_COMMA
  store i64 0, i64* @EXPR_INT
  store i64 1, i64* @EXPR_FLOAT
  store i64 2, i64* @EXPR_STRING
  store i64 3, i64* @EXPR_VAR
  store i64 4, i64* @EXPR_LIST
  store i64 5, i64* @EXPR_MAP
  store i64 6, i64* @EXPR_BINARY
  store i64 7, i64* @EXPR_INDEX
  store i64 8, i64* @EXPR_GET
  store i64 9, i64* @EXPR_CALL
  store i64 10, i64* @EXPR_INPUT
  store i64 11, i64* @EXPR_READ
  store i64 12, i64* @EXPR_MEASURE
  store i64 0, i64* @STMT_LET
  store i64 1, i64* @STMT_ASSIGN
  store i64 2, i64* @STMT_SET
  store i64 3, i64* @STMT_SET_INDEX
  store i64 4, i64* @STMT_APPEND
  store i64 5, i64* @STMT_EXTRACT
  store i64 6, i64* @STMT_PRINT
  store i64 7, i64* @STMT_IF
  store i64 8, i64* @STMT_WHILE
  store i64 9, i64* @STMT_FUNC
  store i64 10, i64* @STMT_RETURN
  store i64 11, i64* @STMT_IMPORT
  store i64 12, i64* @STMT_BREAK
  store i64 13, i64* @STMT_CONTINUE
  store i64 14, i64* @STMT_EXPR
  store i64 15, i64* @STMT_CONST
  store i64 16, i64* @STMT_SHARED
  store i64 0, i64* @VAL_INT
  store i64 1, i64* @VAL_FLOAT
  store i64 2, i64* @VAL_STRING
  store i64 3, i64* @VAL_LIST
  store i64 4, i64* @VAL_MAP
  store i64 5, i64* @VAL_FUNC
  store i64 6, i64* @VAL_VOID
  ret i64 0
}
define i64 @is_digit(i64 %arg_c) {
  %ptr_c = alloca i64
  store i64 %arg_c, i64* %ptr_c
  %ptr_code = alloca i64
  %r1 = load i64, i64* %ptr_c
  %r2 = call i64 @codex(i64 %r1)
  store i64 %r2, i64* %ptr_code
  %r3 = load i64, i64* %ptr_code
  %r5 = icmp sge i64 %r3, 48
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L301, label %L303
L301:
  %r7 = load i64, i64* %ptr_code
  %r9 = icmp sle i64 %r7, 57
  %r8 = zext i1 %r9 to i64
  %r10 = icmp ne i64 %r8, 0
  br i1 %r10, label %L304, label %L306
L304:
  ret i64 1
  br label %L306
L306:
  br label %L303
L303:
  ret i64 0
  ret i64 0
}
define i64 @is_alpha(i64 %arg_c) {
  %ptr_c = alloca i64
  store i64 %arg_c, i64* %ptr_c
  %ptr_code = alloca i64
  %r1 = load i64, i64* %ptr_c
  %r2 = call i64 @codex(i64 %r1)
  store i64 %r2, i64* %ptr_code
  %r3 = load i64, i64* %ptr_code
  %r5 = icmp sge i64 %r3, 65
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L307, label %L309
L307:
  %r7 = load i64, i64* %ptr_code
  %r9 = icmp sle i64 %r7, 90
  %r8 = zext i1 %r9 to i64
  %r10 = icmp ne i64 %r8, 0
  br i1 %r10, label %L310, label %L312
L310:
  ret i64 1
  br label %L312
L312:
  br label %L309
L309:
  %r11 = load i64, i64* %ptr_code
  %r13 = icmp sge i64 %r11, 97
  %r12 = zext i1 %r13 to i64
  %r14 = icmp ne i64 %r12, 0
  br i1 %r14, label %L313, label %L315
L313:
  %r15 = load i64, i64* %ptr_code
  %r17 = icmp sle i64 %r15, 122
  %r16 = zext i1 %r17 to i64
  %r18 = icmp ne i64 %r16, 0
  br i1 %r18, label %L316, label %L318
L316:
  ret i64 1
  br label %L318
L318:
  br label %L315
L315:
  %r19 = load i64, i64* %ptr_c
  %r20 = getelementptr [2 x i8], [2 x i8]* @.str.31, i64 0, i64 0
  %r21 = ptrtoint i8* %r20 to i64
  %r22 = call i64 @_eq(i64 %r19, i64 %r21)
  %r23 = icmp ne i64 %r22, 0
  br i1 %r23, label %L319, label %L321
L319:
  ret i64 1
  br label %L321
L321:
  ret i64 0
  ret i64 0
}
define i64 @is_alnum(i64 %arg_c) {
  %ptr_c = alloca i64
  store i64 %arg_c, i64* %ptr_c
  %ptr_code = alloca i64
  %ptr_res = alloca i64
  %r1 = load i64, i64* %ptr_c
  %r2 = call i64 @codex(i64 %r1)
  store i64 %r2, i64* %ptr_code
  store i64 0, i64* %ptr_res
  %r3 = load i64, i64* %ptr_c
  %r4 = call i64 @is_alpha(i64 %r3)
  %r5 = icmp ne i64 %r4, 0
  br i1 %r5, label %L322, label %L324
L322:
  store i64 1, i64* %ptr_res
  br label %L324
L324:
  %r6 = load i64, i64* %ptr_res
  %r7 = call i64 @_eq(i64 %r6, i64 0)
  %r8 = icmp ne i64 %r7, 0
  br i1 %r8, label %L325, label %L327
L325:
  %r9 = load i64, i64* %ptr_c
  %r10 = call i64 @is_digit(i64 %r9)
  %r11 = icmp ne i64 %r10, 0
  br i1 %r11, label %L328, label %L330
L328:
  store i64 1, i64* %ptr_res
  br label %L330
L330:
  br label %L327
L327:
  %r12 = load i64, i64* %ptr_res
  ret i64 %r12
  ret i64 0
}
define i64 @is_space(i64 %arg_c) {
  %ptr_c = alloca i64
  store i64 %arg_c, i64* %ptr_c
  %ptr_code = alloca i64
  %r1 = load i64, i64* %ptr_c
  %r2 = call i64 @codex(i64 %r1)
  store i64 %r2, i64* %ptr_code
  %r3 = load i64, i64* %ptr_code
  %r4 = call i64 @_eq(i64 %r3, i64 32)
  %r5 = icmp ne i64 %r4, 0
  br i1 %r5, label %L331, label %L333
L331:
  ret i64 1
  br label %L333
L333:
  %r6 = load i64, i64* %ptr_code
  %r7 = call i64 @_eq(i64 %r6, i64 9)
  %r8 = icmp ne i64 %r7, 0
  br i1 %r8, label %L334, label %L336
L334:
  ret i64 1
  br label %L336
L336:
  %r9 = load i64, i64* %ptr_code
  %r10 = call i64 @_eq(i64 %r9, i64 10)
  %r11 = icmp ne i64 %r10, 0
  br i1 %r11, label %L337, label %L339
L337:
  ret i64 1
  br label %L339
L339:
  %r12 = load i64, i64* %ptr_code
  %r13 = call i64 @_eq(i64 %r12, i64 13)
  %r14 = icmp ne i64 %r13, 0
  br i1 %r14, label %L340, label %L342
L340:
  ret i64 1
  br label %L342
L342:
  ret i64 0
  ret i64 0
}
define i64 @make_token(i64 %arg_type, i64 %arg_text) {
  %ptr_type = alloca i64
  store i64 %arg_type, i64* %ptr_type
  %ptr_text = alloca i64
  store i64 %arg_text, i64* %ptr_text
  %r1 = call i64 @_map_new()
  %r2 = getelementptr [5 x i8], [5 x i8]* @.str.32, i64 0, i64 0
  %r3 = ptrtoint i8* %r2 to i64
  %r4 = load i64, i64* %ptr_type
  call i64 @_map_set(i64 %r1, i64 %r3, i64 %r4)
  %r5 = getelementptr [5 x i8], [5 x i8]* @.str.33, i64 0, i64 0
  %r6 = ptrtoint i8* %r5 to i64
  %r7 = load i64, i64* %ptr_text
  call i64 @_map_set(i64 %r1, i64 %r6, i64 %r7)
  ret i64 %r1
  ret i64 0
}
define i64 @get_str_label(i64 %arg_txt) {
  %ptr_txt = alloca i64
  store i64 %arg_txt, i64* %ptr_txt
  %ptr_i = alloca i64
  %ptr_entry = alloca i64
  %ptr_lbl = alloca i64
  %ptr_new_entry = alloca i64
  store i64 0, i64* %ptr_i
  br label %L343
L343:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @str_table
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp slt i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L344, label %L345
L344:
  %r7 = load i64, i64* @str_table
  %r8 = load i64, i64* %ptr_i
  %r9 = call i64 @_get(i64 %r7, i64 %r8)
  store i64 %r9, i64* %ptr_entry
  %r10 = load i64, i64* %ptr_entry
  %r11 = getelementptr [4 x i8], [4 x i8]* @.str.34, i64 0, i64 0
  %r12 = ptrtoint i8* %r11 to i64
  %r13 = call i64 @_get(i64 %r10, i64 %r12)
  %r14 = load i64, i64* %ptr_txt
  %r15 = call i64 @_eq(i64 %r13, i64 %r14)
  %r16 = icmp ne i64 %r15, 0
  br i1 %r16, label %L346, label %L348
L346:
  %r17 = load i64, i64* %ptr_entry
  %r18 = getelementptr [4 x i8], [4 x i8]* @.str.35, i64 0, i64 0
  %r19 = ptrtoint i8* %r18 to i64
  %r20 = call i64 @_get(i64 %r17, i64 %r19)
  ret i64 %r20
  br label %L348
L348:
  %r21 = load i64, i64* %ptr_i
  %r22 = call i64 @_add(i64 %r21, i64 1)
  store i64 %r22, i64* %ptr_i
  br label %L343
L345:
  %r23 = getelementptr [5 x i8], [5 x i8]* @.str.36, i64 0, i64 0
  %r24 = ptrtoint i8* %r23 to i64
  %r25 = load i64, i64* @str_table
  %r26 = call i64 @mensura(i64 %r25)
  %r27 = call i64 @int_to_str(i64 %r26)
  %r28 = call i64 @_add(i64 %r24, i64 %r27)
  store i64 %r28, i64* %ptr_lbl
  %r29 = call i64 @_map_new()
  %r30 = getelementptr [4 x i8], [4 x i8]* @.str.37, i64 0, i64 0
  %r31 = ptrtoint i8* %r30 to i64
  %r32 = load i64, i64* %ptr_txt
  call i64 @_map_set(i64 %r29, i64 %r31, i64 %r32)
  %r33 = getelementptr [4 x i8], [4 x i8]* @.str.38, i64 0, i64 0
  %r34 = ptrtoint i8* %r33 to i64
  %r35 = load i64, i64* %ptr_lbl
  call i64 @_map_set(i64 %r29, i64 %r34, i64 %r35)
  store i64 %r29, i64* %ptr_new_entry
  %r36 = load i64, i64* %ptr_new_entry
  %r37 = load i64, i64* @str_table
  call i64 @_append_poly(i64 %r37, i64 %r36)
  %r38 = load i64, i64* %ptr_lbl
  ret i64 %r38
  ret i64 0
}
define i64 @error_report(i64 %arg_msg) {
  %ptr_msg = alloca i64
  store i64 %arg_msg, i64* %ptr_msg
  store i64 1, i64* @has_error
  ret i64 0
}
define i64 @nasm_bytes(i64 %arg_s) {
  %ptr_s = alloca i64
  store i64 %arg_s, i64* %ptr_s
  %ptr_out = alloca i64
  %ptr_len = alloca i64
  %ptr_i = alloca i64
  %ptr_c = alloca i64
  %ptr_code = alloca i64
  %r1 = getelementptr [1 x i8], [1 x i8]* @.str.39, i64 0, i64 0
  %r2 = ptrtoint i8* %r1 to i64
  store i64 %r2, i64* %ptr_out
  %r3 = load i64, i64* %ptr_s
  %r4 = call i64 @mensura(i64 %r3)
  store i64 %r4, i64* %ptr_len
  store i64 0, i64* %ptr_i
  br label %L349
L349:
  %r5 = load i64, i64* %ptr_i
  %r6 = load i64, i64* %ptr_len
  %r8 = icmp slt i64 %r5, %r6
  %r7 = zext i1 %r8 to i64
  %r9 = icmp ne i64 %r7, 0
  br i1 %r9, label %L350, label %L351
L350:
  %r10 = load i64, i64* %ptr_s
  %r11 = load i64, i64* %ptr_i
  %r12 = call i64 @pars(i64 %r10, i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_c
  %r13 = load i64, i64* %ptr_c
  %r14 = call i64 @codex(i64 %r13)
  store i64 %r14, i64* %ptr_code
  %r15 = load i64, i64* %ptr_out
  %r16 = load i64, i64* %ptr_code
  %r17 = call i64 @int_to_str(i64 %r16)
  %r18 = call i64 @_add(i64 %r15, i64 %r17)
  %r19 = getelementptr [3 x i8], [3 x i8]* @.str.40, i64 0, i64 0
  %r20 = ptrtoint i8* %r19 to i64
  %r21 = call i64 @_add(i64 %r18, i64 %r20)
  store i64 %r21, i64* %ptr_out
  %r22 = load i64, i64* %ptr_i
  %r23 = call i64 @_add(i64 %r22, i64 1)
  store i64 %r23, i64* %ptr_i
  br label %L349
L351:
  %r24 = load i64, i64* %ptr_out
  %r25 = getelementptr [2 x i8], [2 x i8]* @.str.41, i64 0, i64 0
  %r26 = ptrtoint i8* %r25 to i64
  %r27 = call i64 @_add(i64 %r24, i64 %r26)
  ret i64 %r27
  ret i64 0
}
define i64 @is_local(i64 %arg_nm) {
  %ptr_nm = alloca i64
  store i64 %arg_nm, i64* %ptr_nm
  %ptr_i = alloca i64
  %ptr_v = alloca i64
  store i64 0, i64* %ptr_i
  br label %L352
L352:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @local_vars
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp slt i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L353, label %L354
L353:
  %r7 = load i64, i64* @local_vars
  %r8 = load i64, i64* %ptr_i
  %r9 = call i64 @_get(i64 %r7, i64 %r8)
  store i64 %r9, i64* %ptr_v
  %r10 = load i64, i64* %ptr_v
  %r11 = load i64, i64* %ptr_nm
  %r12 = call i64 @_eq(i64 %r10, i64 %r11)
  %r13 = icmp ne i64 %r12, 0
  br i1 %r13, label %L355, label %L357
L355:
  ret i64 1
  br label %L357
L357:
  %r14 = load i64, i64* %ptr_i
  %r15 = call i64 @_add(i64 %r14, i64 1)
  store i64 %r15, i64* %ptr_i
  br label %L352
L354:
  ret i64 0
  ret i64 0
}
define i64 @capere_argumentum(i64 %arg_n) {
  %ptr_n = alloca i64
  store i64 %arg_n, i64* %ptr_n
  %r1 = getelementptr [11 x i8], [11 x i8]* @.str.42, i64 0, i64 0
  %r2 = ptrtoint i8* %r1 to i64
  ret i64 %r2
  ret i64 0
}
define i64 @lex_source(i64 %arg_src) {
  %ptr_src = alloca i64
  store i64 %arg_src, i64* %ptr_src
  %ptr_tokens = alloca i64
  %ptr_len = alloca i64
  %ptr_i = alloca i64
  %ptr_c = alloca i64
  %ptr_next = alloca i64
  %ptr_start = alloca i64
  %ptr_txt = alloca i64
  %ptr_type = alloca i64
  %ptr_loop_c = alloca i64
  %ptr_adv = alloca i64
  %ptr_run_cmt = alloca i64
  %ptr_run_blk = alloca i64
  %ptr_run_str = alloca i64
  %ptr_run_num = alloca i64
  %ptr_run_id = alloca i64
  %ptr_esc = alloca i64
  %ptr_lcode = alloca i64
  %ptr_ok = alloca i64
  %ptr_is_hex = alloca i64
  %ptr_next_char = alloca i64
  %ptr_run_hex = alloca i64
  %ptr_hex_str = alloca i64
  %ptr_keep = alloca i64
  %ptr_next2 = alloca i64
  store i64 1, i64* @use_huge_lists
  %r1 = call i64 @_list_new()
  store i64 %r1, i64* %ptr_tokens
  store i64 0, i64* @use_huge_lists
  %r2 = load i64, i64* %ptr_src
  %r3 = call i64 @mensura(i64 %r2)
  store i64 %r3, i64* %ptr_len
  store i64 0, i64* %ptr_i
  %r4 = getelementptr [1 x i8], [1 x i8]* @.str.43, i64 0, i64 0
  %r5 = ptrtoint i8* %r4 to i64
  store i64 %r5, i64* %ptr_c
  %r6 = getelementptr [1 x i8], [1 x i8]* @.str.44, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  store i64 %r7, i64* %ptr_next
  store i64 0, i64* %ptr_start
  %r8 = getelementptr [1 x i8], [1 x i8]* @.str.45, i64 0, i64 0
  %r9 = ptrtoint i8* %r8 to i64
  store i64 %r9, i64* %ptr_txt
  store i64 0, i64* %ptr_type
  %r10 = getelementptr [1 x i8], [1 x i8]* @.str.46, i64 0, i64 0
  %r11 = ptrtoint i8* %r10 to i64
  store i64 %r11, i64* %ptr_loop_c
  store i64 0, i64* %ptr_adv
  store i64 0, i64* %ptr_run_cmt
  store i64 0, i64* %ptr_run_blk
  store i64 0, i64* %ptr_run_str
  store i64 0, i64* %ptr_run_num
  store i64 0, i64* %ptr_run_id
  %r12 = getelementptr [1 x i8], [1 x i8]* @.str.47, i64 0, i64 0
  %r13 = ptrtoint i8* %r12 to i64
  store i64 %r13, i64* %ptr_esc
  store i64 0, i64* %ptr_lcode
  store i64 0, i64* %ptr_ok
  br label %L358
L358:
  %r14 = load i64, i64* %ptr_i
  %r15 = load i64, i64* %ptr_len
  %r17 = icmp slt i64 %r14, %r15
  %r16 = zext i1 %r17 to i64
  %r18 = icmp ne i64 %r16, 0
  br i1 %r18, label %L359, label %L360
L359:
  %r19 = load i64, i64* %ptr_src
  %r20 = load i64, i64* %ptr_i
  %r21 = call i64 @pars(i64 %r19, i64 %r20, i64 1)
  store i64 %r21, i64* %ptr_c
  %r22 = load i64, i64* %ptr_c
  %r23 = call i64 @is_space(i64 %r22)
  %r24 = icmp ne i64 %r23, 0
  br i1 %r24, label %L361, label %L362
L361:
  %r25 = load i64, i64* %ptr_i
  %r26 = call i64 @_add(i64 %r25, i64 1)
  store i64 %r26, i64* %ptr_i
  br label %L363
L362:
  %r27 = load i64, i64* %ptr_c
  %r28 = getelementptr [2 x i8], [2 x i8]* @.str.48, i64 0, i64 0
  %r29 = ptrtoint i8* %r28 to i64
  %r30 = call i64 @_eq(i64 %r27, i64 %r29)
  %r31 = icmp ne i64 %r30, 0
  br i1 %r31, label %L364, label %L365
L364:
  %r32 = load i64, i64* %ptr_src
  %r33 = load i64, i64* %ptr_i
  %r34 = call i64 @_add(i64 %r33, i64 1)
  %r35 = call i64 @pars(i64 %r32, i64 %r34, i64 1)
  store i64 %r35, i64* %ptr_next
  %r36 = load i64, i64* %ptr_next
  %r37 = getelementptr [2 x i8], [2 x i8]* @.str.49, i64 0, i64 0
  %r38 = ptrtoint i8* %r37 to i64
  %r39 = call i64 @_eq(i64 %r36, i64 %r38)
  %r40 = icmp ne i64 %r39, 0
  br i1 %r40, label %L367, label %L368
L367:
  store i64 1, i64* %ptr_run_cmt
  br label %L370
L370:
  %r41 = load i64, i64* %ptr_run_cmt
  %r42 = icmp ne i64 %r41, 0
  br i1 %r42, label %L371, label %L372
L371:
  %r43 = load i64, i64* %ptr_i
  %r44 = load i64, i64* %ptr_len
  %r46 = icmp sge i64 %r43, %r44
  %r45 = zext i1 %r46 to i64
  %r47 = icmp ne i64 %r45, 0
  br i1 %r47, label %L373, label %L375
L373:
  store i64 0, i64* %ptr_run_cmt
  br label %L375
L375:
  %r48 = load i64, i64* %ptr_run_cmt
  %r49 = icmp ne i64 %r48, 0
  br i1 %r49, label %L376, label %L378
L376:
  %r50 = load i64, i64* %ptr_src
  %r51 = load i64, i64* %ptr_i
  %r52 = call i64 @pars(i64 %r50, i64 %r51, i64 1)
  store i64 %r52, i64* %ptr_loop_c
  %r53 = load i64, i64* %ptr_loop_c
  %r54 = call i64 @codex(i64 %r53)
  %r55 = call i64 @_eq(i64 %r54, i64 10)
  %r56 = icmp ne i64 %r55, 0
  br i1 %r56, label %L379, label %L381
L379:
  store i64 0, i64* %ptr_run_cmt
  br label %L381
L381:
  %r57 = load i64, i64* %ptr_run_cmt
  %r58 = icmp ne i64 %r57, 0
  br i1 %r58, label %L382, label %L384
L382:
  %r59 = load i64, i64* %ptr_i
  %r60 = call i64 @_add(i64 %r59, i64 1)
  store i64 %r60, i64* %ptr_i
  br label %L384
L384:
  br label %L378
L378:
  br label %L370
L372:
  br label %L369
L368:
  %r61 = load i64, i64* %ptr_next
  %r62 = getelementptr [2 x i8], [2 x i8]* @.str.50, i64 0, i64 0
  %r63 = ptrtoint i8* %r62 to i64
  %r64 = call i64 @_eq(i64 %r61, i64 %r63)
  %r65 = icmp ne i64 %r64, 0
  br i1 %r65, label %L385, label %L386
L385:
  %r66 = load i64, i64* %ptr_i
  %r67 = call i64 @_add(i64 %r66, i64 2)
  store i64 %r67, i64* %ptr_i
  store i64 1, i64* %ptr_run_blk
  br label %L388
L388:
  %r68 = load i64, i64* %ptr_run_blk
  %r69 = icmp ne i64 %r68, 0
  br i1 %r69, label %L389, label %L390
L389:
  %r70 = load i64, i64* %ptr_i
  %r71 = load i64, i64* %ptr_len
  %r73 = icmp sge i64 %r70, %r71
  %r72 = zext i1 %r73 to i64
  %r74 = icmp ne i64 %r72, 0
  br i1 %r74, label %L391, label %L393
L391:
  store i64 0, i64* %ptr_run_blk
  br label %L393
L393:
  %r75 = load i64, i64* %ptr_run_blk
  %r76 = icmp ne i64 %r75, 0
  br i1 %r76, label %L394, label %L396
L394:
  %r77 = load i64, i64* %ptr_src
  %r78 = load i64, i64* %ptr_i
  %r79 = call i64 @pars(i64 %r77, i64 %r78, i64 1)
  %r80 = getelementptr [2 x i8], [2 x i8]* @.str.52, i64 0, i64 0
  %r81 = ptrtoint i8* %r80 to i64
  %r82 = call i64 @_eq(i64 %r79, i64 %r81)
  store i64 0, i64* @.sc.51
  %r84 = icmp ne i64 %r82, 0
  br i1 %r84, label %L397, label %L398
L397:
  %r85 = load i64, i64* %ptr_src
  %r86 = load i64, i64* %ptr_i
  %r87 = call i64 @_add(i64 %r86, i64 1)
  %r88 = call i64 @pars(i64 %r85, i64 %r87, i64 1)
  %r89 = getelementptr [2 x i8], [2 x i8]* @.str.53, i64 0, i64 0
  %r90 = ptrtoint i8* %r89 to i64
  %r91 = call i64 @_eq(i64 %r88, i64 %r90)
  %r92 = icmp ne i64 %r91, 0
  %r93 = zext i1 %r92 to i64
  store i64 %r93, i64* @.sc.51
  br label %L398
L398:
  %r83 = load i64, i64* @.sc.51
  %r94 = icmp ne i64 %r83, 0
  br i1 %r94, label %L399, label %L401
L399:
  %r95 = load i64, i64* %ptr_i
  %r96 = call i64 @_add(i64 %r95, i64 2)
  store i64 %r96, i64* %ptr_i
  store i64 0, i64* %ptr_run_blk
  br label %L401
L401:
  %r97 = load i64, i64* %ptr_run_blk
  %r98 = icmp ne i64 %r97, 0
  br i1 %r98, label %L402, label %L404
L402:
  %r99 = load i64, i64* %ptr_i
  %r100 = call i64 @_add(i64 %r99, i64 1)
  store i64 %r100, i64* %ptr_i
  br label %L404
L404:
  br label %L396
L396:
  br label %L388
L390:
  br label %L387
L386:
  %r101 = load i64, i64* @TOK_OP
  %r102 = getelementptr [2 x i8], [2 x i8]* @.str.54, i64 0, i64 0
  %r103 = ptrtoint i8* %r102 to i64
  %r104 = call i64 @make_token(i64 %r101, i64 %r103)
  %r105 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r105, i64 %r104)
  %r106 = load i64, i64* %ptr_i
  %r107 = call i64 @_add(i64 %r106, i64 1)
  store i64 %r107, i64* %ptr_i
  br label %L387
L387:
  br label %L369
L369:
  br label %L366
L365:
  %r108 = load i64, i64* %ptr_c
  %r109 = getelementptr [2 x i8], [2 x i8]* @.str.55, i64 0, i64 0
  %r110 = ptrtoint i8* %r109 to i64
  %r111 = call i64 @_eq(i64 %r108, i64 %r110)
  %r112 = icmp ne i64 %r111, 0
  br i1 %r112, label %L405, label %L406
L405:
  %r113 = load i64, i64* %ptr_i
  %r114 = call i64 @_add(i64 %r113, i64 1)
  store i64 %r114, i64* %ptr_i
  %r115 = getelementptr [1 x i8], [1 x i8]* @.str.56, i64 0, i64 0
  %r116 = ptrtoint i8* %r115 to i64
  store i64 %r116, i64* %ptr_txt
  store i64 1, i64* %ptr_run_str
  br label %L408
L408:
  %r117 = load i64, i64* %ptr_run_str
  %r118 = icmp ne i64 %r117, 0
  br i1 %r118, label %L409, label %L410
L409:
  %r119 = load i64, i64* %ptr_i
  %r120 = load i64, i64* %ptr_len
  %r122 = icmp sge i64 %r119, %r120
  %r121 = zext i1 %r122 to i64
  %r123 = icmp ne i64 %r121, 0
  br i1 %r123, label %L411, label %L413
L411:
  store i64 0, i64* %ptr_run_str
  br label %L413
L413:
  %r124 = load i64, i64* %ptr_run_str
  %r125 = icmp ne i64 %r124, 0
  br i1 %r125, label %L414, label %L416
L414:
  %r126 = load i64, i64* %ptr_src
  %r127 = load i64, i64* %ptr_i
  %r128 = call i64 @pars(i64 %r126, i64 %r127, i64 1)
  store i64 %r128, i64* %ptr_loop_c
  %r129 = load i64, i64* %ptr_loop_c
  %r130 = getelementptr [2 x i8], [2 x i8]* @.str.57, i64 0, i64 0
  %r131 = ptrtoint i8* %r130 to i64
  %r132 = call i64 @_eq(i64 %r129, i64 %r131)
  %r133 = icmp ne i64 %r132, 0
  br i1 %r133, label %L417, label %L419
L417:
  store i64 0, i64* %ptr_run_str
  br label %L419
L419:
  %r134 = load i64, i64* %ptr_run_str
  %r135 = icmp ne i64 %r134, 0
  br i1 %r135, label %L420, label %L422
L420:
  %r136 = load i64, i64* %ptr_loop_c
  %r137 = getelementptr [2 x i8], [2 x i8]* @.str.58, i64 0, i64 0
  %r138 = ptrtoint i8* %r137 to i64
  %r139 = call i64 @_eq(i64 %r136, i64 %r138)
  %r140 = icmp ne i64 %r139, 0
  br i1 %r140, label %L423, label %L424
L423:
  %r141 = load i64, i64* %ptr_i
  %r142 = call i64 @_add(i64 %r141, i64 1)
  store i64 %r142, i64* %ptr_i
  %r143 = load i64, i64* %ptr_src
  %r144 = load i64, i64* %ptr_i
  %r145 = call i64 @pars(i64 %r143, i64 %r144, i64 1)
  store i64 %r145, i64* %ptr_esc
  %r146 = load i64, i64* %ptr_esc
  %r147 = getelementptr [2 x i8], [2 x i8]* @.str.59, i64 0, i64 0
  %r148 = ptrtoint i8* %r147 to i64
  %r149 = call i64 @_eq(i64 %r146, i64 %r148)
  %r150 = icmp ne i64 %r149, 0
  br i1 %r150, label %L426, label %L427
L426:
  %r151 = load i64, i64* %ptr_txt
  %r152 = call i64 @signum_ex(i64 10)
  %r153 = call i64 @_add(i64 %r151, i64 %r152)
  store i64 %r153, i64* %ptr_txt
  br label %L428
L427:
  %r154 = load i64, i64* %ptr_esc
  %r155 = getelementptr [2 x i8], [2 x i8]* @.str.60, i64 0, i64 0
  %r156 = ptrtoint i8* %r155 to i64
  %r157 = call i64 @_eq(i64 %r154, i64 %r156)
  %r158 = icmp ne i64 %r157, 0
  br i1 %r158, label %L429, label %L430
L429:
  %r159 = load i64, i64* %ptr_txt
  %r160 = call i64 @signum_ex(i64 9)
  %r161 = call i64 @_add(i64 %r159, i64 %r160)
  store i64 %r161, i64* %ptr_txt
  br label %L431
L430:
  %r162 = load i64, i64* %ptr_esc
  %r163 = getelementptr [2 x i8], [2 x i8]* @.str.61, i64 0, i64 0
  %r164 = ptrtoint i8* %r163 to i64
  %r165 = call i64 @_eq(i64 %r162, i64 %r164)
  %r166 = icmp ne i64 %r165, 0
  br i1 %r166, label %L432, label %L433
L432:
  %r167 = load i64, i64* %ptr_txt
  %r168 = getelementptr [2 x i8], [2 x i8]* @.str.62, i64 0, i64 0
  %r169 = ptrtoint i8* %r168 to i64
  %r170 = call i64 @_add(i64 %r167, i64 %r169)
  store i64 %r170, i64* %ptr_txt
  br label %L434
L433:
  %r171 = load i64, i64* %ptr_esc
  %r172 = getelementptr [2 x i8], [2 x i8]* @.str.63, i64 0, i64 0
  %r173 = ptrtoint i8* %r172 to i64
  %r174 = call i64 @_eq(i64 %r171, i64 %r173)
  %r175 = icmp ne i64 %r174, 0
  br i1 %r175, label %L435, label %L436
L435:
  %r176 = load i64, i64* %ptr_txt
  %r177 = getelementptr [2 x i8], [2 x i8]* @.str.64, i64 0, i64 0
  %r178 = ptrtoint i8* %r177 to i64
  %r179 = call i64 @_add(i64 %r176, i64 %r178)
  store i64 %r179, i64* %ptr_txt
  br label %L437
L436:
  %r180 = load i64, i64* %ptr_txt
  %r181 = load i64, i64* %ptr_esc
  %r182 = call i64 @_add(i64 %r180, i64 %r181)
  store i64 %r182, i64* %ptr_txt
  br label %L437
L437:
  br label %L434
L434:
  br label %L431
L431:
  br label %L428
L428:
  br label %L425
L424:
  %r183 = load i64, i64* %ptr_txt
  %r184 = load i64, i64* %ptr_loop_c
  %r185 = call i64 @_add(i64 %r183, i64 %r184)
  store i64 %r185, i64* %ptr_txt
  br label %L425
L425:
  %r186 = load i64, i64* %ptr_i
  %r187 = call i64 @_add(i64 %r186, i64 1)
  store i64 %r187, i64* %ptr_i
  br label %L422
L422:
  br label %L416
L416:
  br label %L408
L410:
  %r188 = load i64, i64* @TOK_STRING
  %r189 = load i64, i64* %ptr_txt
  %r190 = call i64 @make_token(i64 %r188, i64 %r189)
  %r191 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r191, i64 %r190)
  %r192 = load i64, i64* %ptr_i
  %r193 = call i64 @_add(i64 %r192, i64 1)
  store i64 %r193, i64* %ptr_i
  br label %L407
L406:
  %r194 = load i64, i64* %ptr_c
  %r195 = call i64 @is_digit(i64 %r194)
  %r196 = icmp ne i64 %r195, 0
  br i1 %r196, label %L438, label %L439
L438:
  %r197 = load i64, i64* %ptr_i
  store i64 %r197, i64* %ptr_start
  store i64 0, i64* %ptr_is_hex
  %r198 = load i64, i64* %ptr_c
  %r199 = getelementptr [2 x i8], [2 x i8]* @.str.65, i64 0, i64 0
  %r200 = ptrtoint i8* %r199 to i64
  %r201 = call i64 @_eq(i64 %r198, i64 %r200)
  %r202 = icmp ne i64 %r201, 0
  br i1 %r202, label %L441, label %L443
L441:
  %r203 = load i64, i64* %ptr_src
  %r204 = load i64, i64* %ptr_i
  %r205 = call i64 @_add(i64 %r204, i64 1)
  %r206 = call i64 @pars(i64 %r203, i64 %r205, i64 1)
  store i64 %r206, i64* %ptr_next_char
  %r207 = load i64, i64* %ptr_next_char
  %r208 = getelementptr [2 x i8], [2 x i8]* @.str.66, i64 0, i64 0
  %r209 = ptrtoint i8* %r208 to i64
  %r210 = call i64 @_eq(i64 %r207, i64 %r209)
  %r211 = icmp ne i64 %r210, 0
  br i1 %r211, label %L444, label %L446
L444:
  store i64 1, i64* %ptr_is_hex
  br label %L446
L446:
  %r212 = load i64, i64* %ptr_next_char
  %r213 = getelementptr [2 x i8], [2 x i8]* @.str.67, i64 0, i64 0
  %r214 = ptrtoint i8* %r213 to i64
  %r215 = call i64 @_eq(i64 %r212, i64 %r214)
  %r216 = icmp ne i64 %r215, 0
  br i1 %r216, label %L447, label %L449
L447:
  store i64 1, i64* %ptr_is_hex
  br label %L449
L449:
  br label %L443
L443:
  %r217 = load i64, i64* %ptr_is_hex
  %r218 = icmp ne i64 %r217, 0
  br i1 %r218, label %L450, label %L451
L450:
  %r219 = load i64, i64* %ptr_i
  %r220 = call i64 @_add(i64 %r219, i64 2)
  store i64 %r220, i64* %ptr_i
  %r221 = load i64, i64* %ptr_i
  store i64 %r221, i64* %ptr_start
  store i64 1, i64* %ptr_run_hex
  br label %L453
L453:
  %r222 = load i64, i64* %ptr_run_hex
  %r223 = icmp ne i64 %r222, 0
  br i1 %r223, label %L454, label %L455
L454:
  %r224 = load i64, i64* %ptr_i
  %r225 = load i64, i64* %ptr_len
  %r227 = icmp sge i64 %r224, %r225
  %r226 = zext i1 %r227 to i64
  %r228 = icmp ne i64 %r226, 0
  br i1 %r228, label %L456, label %L458
L456:
  store i64 0, i64* %ptr_run_hex
  br label %L458
L458:
  %r229 = load i64, i64* %ptr_run_hex
  %r230 = icmp ne i64 %r229, 0
  br i1 %r230, label %L459, label %L461
L459:
  %r231 = load i64, i64* %ptr_src
  %r232 = load i64, i64* %ptr_i
  %r233 = call i64 @pars(i64 %r231, i64 %r232, i64 1)
  store i64 %r233, i64* %ptr_loop_c
  %r234 = load i64, i64* %ptr_loop_c
  %r235 = call i64 @is_alnum(i64 %r234)
  %r236 = call i64 @_eq(i64 %r235, i64 0)
  %r237 = icmp ne i64 %r236, 0
  br i1 %r237, label %L462, label %L464
L462:
  store i64 0, i64* %ptr_run_hex
  br label %L464
L464:
  %r238 = load i64, i64* %ptr_run_hex
  %r239 = icmp ne i64 %r238, 0
  br i1 %r239, label %L465, label %L467
L465:
  %r240 = load i64, i64* %ptr_i
  %r241 = call i64 @_add(i64 %r240, i64 1)
  store i64 %r241, i64* %ptr_i
  br label %L467
L467:
  br label %L461
L461:
  br label %L453
L455:
  %r242 = load i64, i64* %ptr_src
  %r243 = load i64, i64* %ptr_start
  %r244 = load i64, i64* %ptr_i
  %r245 = load i64, i64* %ptr_start
  %r246 = sub i64 %r244, %r245
  %r247 = call i64 @pars(i64 %r242, i64 %r243, i64 %r246)
  store i64 %r247, i64* %ptr_hex_str
  %r248 = load i64, i64* @TOK_INT
  %r249 = load i64, i64* %ptr_hex_str
  %r250 = call i64 @hex_to_dec(i64 %r249)
  %r251 = call i64 @int_to_str(i64 %r250)
  %r252 = call i64 @make_token(i64 %r248, i64 %r251)
  %r253 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r253, i64 %r252)
  br label %L452
L451:
  store i64 1, i64* %ptr_run_num
  br label %L468
L468:
  %r254 = load i64, i64* %ptr_run_num
  %r255 = icmp ne i64 %r254, 0
  br i1 %r255, label %L469, label %L470
L469:
  %r256 = load i64, i64* %ptr_i
  %r257 = load i64, i64* %ptr_len
  %r259 = icmp sge i64 %r256, %r257
  %r258 = zext i1 %r259 to i64
  %r260 = icmp ne i64 %r258, 0
  br i1 %r260, label %L471, label %L473
L471:
  store i64 0, i64* %ptr_run_num
  br label %L473
L473:
  %r261 = load i64, i64* %ptr_run_num
  %r262 = icmp ne i64 %r261, 0
  br i1 %r262, label %L474, label %L476
L474:
  %r263 = load i64, i64* %ptr_src
  %r264 = load i64, i64* %ptr_i
  %r265 = call i64 @pars(i64 %r263, i64 %r264, i64 1)
  store i64 %r265, i64* %ptr_loop_c
  store i64 0, i64* %ptr_keep
  %r266 = load i64, i64* %ptr_loop_c
  %r267 = call i64 @is_digit(i64 %r266)
  %r268 = icmp ne i64 %r267, 0
  br i1 %r268, label %L477, label %L479
L477:
  store i64 1, i64* %ptr_keep
  br label %L479
L479:
  %r269 = load i64, i64* %ptr_loop_c
  %r270 = getelementptr [2 x i8], [2 x i8]* @.str.68, i64 0, i64 0
  %r271 = ptrtoint i8* %r270 to i64
  %r272 = call i64 @_eq(i64 %r269, i64 %r271)
  %r273 = icmp ne i64 %r272, 0
  br i1 %r273, label %L480, label %L482
L480:
  store i64 1, i64* %ptr_keep
  br label %L482
L482:
  %r274 = load i64, i64* %ptr_keep
  %r275 = call i64 @_eq(i64 %r274, i64 0)
  %r276 = icmp ne i64 %r275, 0
  br i1 %r276, label %L483, label %L485
L483:
  store i64 0, i64* %ptr_run_num
  br label %L485
L485:
  %r277 = load i64, i64* %ptr_run_num
  %r278 = icmp ne i64 %r277, 0
  br i1 %r278, label %L486, label %L488
L486:
  %r279 = load i64, i64* %ptr_i
  %r280 = call i64 @_add(i64 %r279, i64 1)
  store i64 %r280, i64* %ptr_i
  br label %L488
L488:
  br label %L476
L476:
  br label %L468
L470:
  %r281 = load i64, i64* %ptr_src
  %r282 = load i64, i64* %ptr_start
  %r283 = load i64, i64* %ptr_i
  %r284 = load i64, i64* %ptr_start
  %r285 = sub i64 %r283, %r284
  %r286 = call i64 @pars(i64 %r281, i64 %r282, i64 %r285)
  store i64 %r286, i64* %ptr_txt
  %r287 = load i64, i64* @TOK_INT
  %r288 = load i64, i64* %ptr_txt
  %r289 = call i64 @make_token(i64 %r287, i64 %r288)
  %r290 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r290, i64 %r289)
  br label %L452
L452:
  br label %L440
L439:
  %r291 = load i64, i64* %ptr_c
  %r292 = call i64 @is_alpha(i64 %r291)
  %r293 = icmp ne i64 %r292, 0
  br i1 %r293, label %L489, label %L490
L489:
  %r294 = load i64, i64* %ptr_i
  store i64 %r294, i64* %ptr_start
  store i64 1, i64* %ptr_run_id
  br label %L492
L492:
  %r295 = load i64, i64* %ptr_run_id
  %r296 = icmp ne i64 %r295, 0
  br i1 %r296, label %L493, label %L494
L493:
  %r297 = load i64, i64* %ptr_i
  %r298 = load i64, i64* %ptr_len
  %r300 = icmp sge i64 %r297, %r298
  %r299 = zext i1 %r300 to i64
  %r301 = icmp ne i64 %r299, 0
  br i1 %r301, label %L495, label %L497
L495:
  store i64 0, i64* %ptr_run_id
  br label %L497
L497:
  %r302 = load i64, i64* %ptr_run_id
  %r303 = icmp ne i64 %r302, 0
  br i1 %r303, label %L498, label %L500
L498:
  %r304 = load i64, i64* %ptr_src
  %r305 = load i64, i64* %ptr_i
  %r306 = call i64 @pars(i64 %r304, i64 %r305, i64 1)
  store i64 %r306, i64* %ptr_loop_c
  %r307 = load i64, i64* %ptr_loop_c
  %r308 = call i64 @codex(i64 %r307)
  store i64 %r308, i64* %ptr_lcode
  store i64 0, i64* %ptr_ok
  %r309 = load i64, i64* %ptr_lcode
  %r311 = icmp sge i64 %r309, 48
  %r310 = zext i1 %r311 to i64
  %r312 = icmp ne i64 %r310, 0
  br i1 %r312, label %L501, label %L503
L501:
  %r313 = load i64, i64* %ptr_lcode
  %r315 = icmp sle i64 %r313, 57
  %r314 = zext i1 %r315 to i64
  %r316 = icmp ne i64 %r314, 0
  br i1 %r316, label %L504, label %L506
L504:
  store i64 1, i64* %ptr_ok
  br label %L506
L506:
  br label %L503
L503:
  %r317 = load i64, i64* %ptr_lcode
  %r319 = icmp sge i64 %r317, 65
  %r318 = zext i1 %r319 to i64
  %r320 = icmp ne i64 %r318, 0
  br i1 %r320, label %L507, label %L509
L507:
  %r321 = load i64, i64* %ptr_lcode
  %r323 = icmp sle i64 %r321, 90
  %r322 = zext i1 %r323 to i64
  %r324 = icmp ne i64 %r322, 0
  br i1 %r324, label %L510, label %L512
L510:
  store i64 1, i64* %ptr_ok
  br label %L512
L512:
  br label %L509
L509:
  %r325 = load i64, i64* %ptr_lcode
  %r327 = icmp sge i64 %r325, 97
  %r326 = zext i1 %r327 to i64
  %r328 = icmp ne i64 %r326, 0
  br i1 %r328, label %L513, label %L515
L513:
  %r329 = load i64, i64* %ptr_lcode
  %r331 = icmp sle i64 %r329, 122
  %r330 = zext i1 %r331 to i64
  %r332 = icmp ne i64 %r330, 0
  br i1 %r332, label %L516, label %L518
L516:
  store i64 1, i64* %ptr_ok
  br label %L518
L518:
  br label %L515
L515:
  %r333 = load i64, i64* %ptr_lcode
  %r334 = call i64 @_eq(i64 %r333, i64 95)
  %r335 = icmp ne i64 %r334, 0
  br i1 %r335, label %L519, label %L521
L519:
  store i64 1, i64* %ptr_ok
  br label %L521
L521:
  %r336 = load i64, i64* %ptr_ok
  %r337 = call i64 @_eq(i64 %r336, i64 0)
  %r338 = icmp ne i64 %r337, 0
  br i1 %r338, label %L522, label %L524
L522:
  store i64 0, i64* %ptr_run_id
  br label %L524
L524:
  %r339 = load i64, i64* %ptr_run_id
  %r340 = icmp ne i64 %r339, 0
  br i1 %r340, label %L525, label %L527
L525:
  %r341 = load i64, i64* %ptr_i
  %r342 = call i64 @_add(i64 %r341, i64 1)
  store i64 %r342, i64* %ptr_i
  br label %L527
L527:
  br label %L500
L500:
  br label %L492
L494:
  %r343 = load i64, i64* %ptr_src
  %r344 = load i64, i64* %ptr_start
  %r345 = load i64, i64* %ptr_i
  %r346 = load i64, i64* %ptr_start
  %r347 = sub i64 %r345, %r346
  %r348 = call i64 @pars(i64 %r343, i64 %r344, i64 %r347)
  store i64 %r348, i64* %ptr_txt
  store i64 4, i64* %ptr_type
  %r349 = load i64, i64* %ptr_txt
  %r350 = getelementptr [4 x i8], [4 x i8]* @.str.69, i64 0, i64 0
  %r351 = ptrtoint i8* %r350 to i64
  %r352 = call i64 @_eq(i64 %r349, i64 %r351)
  %r353 = icmp ne i64 %r352, 0
  br i1 %r353, label %L528, label %L530
L528:
  store i64 5, i64* %ptr_type
  br label %L530
L530:
  %r354 = load i64, i64* %ptr_txt
  %r355 = getelementptr [5 x i8], [5 x i8]* @.str.70, i64 0, i64 0
  %r356 = ptrtoint i8* %r355 to i64
  %r357 = call i64 @_eq(i64 %r354, i64 %r356)
  %r358 = icmp ne i64 %r357, 0
  br i1 %r358, label %L531, label %L533
L531:
  store i64 5, i64* %ptr_type
  br label %L533
L533:
  %r359 = load i64, i64* %ptr_txt
  %r360 = getelementptr [6 x i8], [6 x i8]* @.str.71, i64 0, i64 0
  %r361 = ptrtoint i8* %r360 to i64
  %r362 = call i64 @_eq(i64 %r359, i64 %r361)
  %r363 = icmp ne i64 %r362, 0
  br i1 %r363, label %L534, label %L536
L534:
  store i64 5, i64* %ptr_type
  br label %L536
L536:
  %r364 = load i64, i64* %ptr_txt
  %r365 = getelementptr [7 x i8], [7 x i8]* @.str.72, i64 0, i64 0
  %r366 = ptrtoint i8* %r365 to i64
  %r367 = call i64 @_eq(i64 %r364, i64 %r366)
  %r368 = icmp ne i64 %r367, 0
  br i1 %r368, label %L537, label %L539
L537:
  store i64 6, i64* %ptr_type
  br label %L539
L539:
  %r369 = load i64, i64* %ptr_txt
  %r370 = getelementptr [8 x i8], [8 x i8]* @.str.73, i64 0, i64 0
  %r371 = ptrtoint i8* %r370 to i64
  %r372 = call i64 @_eq(i64 %r369, i64 %r371)
  %r373 = icmp ne i64 %r372, 0
  br i1 %r373, label %L540, label %L542
L540:
  store i64 6, i64* %ptr_type
  br label %L542
L542:
  %r374 = load i64, i64* %ptr_txt
  %r375 = getelementptr [10 x i8], [10 x i8]* @.str.74, i64 0, i64 0
  %r376 = ptrtoint i8* %r375 to i64
  %r377 = call i64 @_eq(i64 %r374, i64 %r376)
  %r378 = icmp ne i64 %r377, 0
  br i1 %r378, label %L543, label %L545
L543:
  store i64 6, i64* %ptr_type
  br label %L545
L545:
  %r379 = load i64, i64* %ptr_txt
  %r380 = getelementptr [3 x i8], [3 x i8]* @.str.75, i64 0, i64 0
  %r381 = ptrtoint i8* %r380 to i64
  %r382 = call i64 @_eq(i64 %r379, i64 %r381)
  %r383 = icmp ne i64 %r382, 0
  br i1 %r383, label %L546, label %L548
L546:
  store i64 7, i64* %ptr_type
  br label %L548
L548:
  %r384 = load i64, i64* %ptr_txt
  %r385 = getelementptr [7 x i8], [7 x i8]* @.str.76, i64 0, i64 0
  %r386 = ptrtoint i8* %r385 to i64
  %r387 = call i64 @_eq(i64 %r384, i64 %r386)
  %r388 = icmp ne i64 %r387, 0
  br i1 %r388, label %L549, label %L551
L549:
  store i64 8, i64* %ptr_type
  br label %L551
L551:
  %r389 = load i64, i64* %ptr_txt
  %r390 = getelementptr [4 x i8], [4 x i8]* @.str.77, i64 0, i64 0
  %r391 = ptrtoint i8* %r390 to i64
  %r392 = call i64 @_eq(i64 %r389, i64 %r391)
  %r393 = icmp ne i64 %r392, 0
  br i1 %r393, label %L552, label %L554
L552:
  store i64 9, i64* %ptr_type
  br label %L554
L554:
  %r394 = load i64, i64* %ptr_txt
  %r395 = getelementptr [5 x i8], [5 x i8]* @.str.78, i64 0, i64 0
  %r396 = ptrtoint i8* %r395 to i64
  %r397 = call i64 @_eq(i64 %r394, i64 %r396)
  %r398 = icmp ne i64 %r397, 0
  br i1 %r398, label %L555, label %L557
L555:
  store i64 10, i64* %ptr_type
  br label %L557
L557:
  %r399 = load i64, i64* %ptr_txt
  %r400 = getelementptr [6 x i8], [6 x i8]* @.str.79, i64 0, i64 0
  %r401 = ptrtoint i8* %r400 to i64
  %r402 = call i64 @_eq(i64 %r399, i64 %r401)
  %r403 = icmp ne i64 %r402, 0
  br i1 %r403, label %L558, label %L560
L558:
  store i64 11, i64* %ptr_type
  br label %L560
L560:
  %r404 = load i64, i64* %ptr_txt
  %r405 = getelementptr [10 x i8], [10 x i8]* @.str.80, i64 0, i64 0
  %r406 = ptrtoint i8* %r405 to i64
  %r407 = call i64 @_eq(i64 %r404, i64 %r406)
  %r408 = icmp ne i64 %r407, 0
  br i1 %r408, label %L561, label %L563
L561:
  store i64 12, i64* %ptr_type
  br label %L563
L563:
  %r409 = load i64, i64* %ptr_txt
  %r410 = getelementptr [8 x i8], [8 x i8]* @.str.81, i64 0, i64 0
  %r411 = ptrtoint i8* %r410 to i64
  %r412 = call i64 @_eq(i64 %r409, i64 %r411)
  %r413 = icmp ne i64 %r412, 0
  br i1 %r413, label %L564, label %L566
L564:
  store i64 13, i64* %ptr_type
  br label %L566
L566:
  %r414 = load i64, i64* %ptr_txt
  %r415 = getelementptr [10 x i8], [10 x i8]* @.str.82, i64 0, i64 0
  %r416 = ptrtoint i8* %r415 to i64
  %r417 = call i64 @_eq(i64 %r414, i64 %r416)
  %r418 = icmp ne i64 %r417, 0
  br i1 %r418, label %L567, label %L569
L567:
  store i64 20, i64* %ptr_type
  br label %L569
L569:
  %r419 = load i64, i64* %ptr_txt
  %r420 = getelementptr [9 x i8], [9 x i8]* @.str.83, i64 0, i64 0
  %r421 = ptrtoint i8* %r420 to i64
  %r422 = call i64 @_eq(i64 %r419, i64 %r421)
  %r423 = icmp ne i64 %r422, 0
  br i1 %r423, label %L570, label %L572
L570:
  store i64 35, i64* %ptr_type
  br label %L572
L572:
  %r424 = load i64, i64* %ptr_txt
  %r425 = getelementptr [9 x i8], [9 x i8]* @.str.84, i64 0, i64 0
  %r426 = ptrtoint i8* %r425 to i64
  %r427 = call i64 @_eq(i64 %r424, i64 %r426)
  %r428 = icmp ne i64 %r427, 0
  br i1 %r428, label %L573, label %L575
L573:
  store i64 36, i64* %ptr_type
  br label %L575
L575:
  %r429 = load i64, i64* %ptr_txt
  %r430 = getelementptr [4 x i8], [4 x i8]* @.str.85, i64 0, i64 0
  %r431 = ptrtoint i8* %r430 to i64
  %r432 = call i64 @_eq(i64 %r429, i64 %r431)
  %r433 = icmp ne i64 %r432, 0
  br i1 %r433, label %L576, label %L578
L576:
  store i64 37, i64* %ptr_type
  %r434 = getelementptr [2 x i8], [2 x i8]* @.str.86, i64 0, i64 0
  %r435 = ptrtoint i8* %r434 to i64
  store i64 %r435, i64* %ptr_txt
  br label %L578
L578:
  %r436 = load i64, i64* %ptr_txt
  %r437 = getelementptr [3 x i8], [3 x i8]* @.str.87, i64 0, i64 0
  %r438 = ptrtoint i8* %r437 to i64
  %r439 = call i64 @_eq(i64 %r436, i64 %r438)
  %r440 = icmp ne i64 %r439, 0
  br i1 %r440, label %L579, label %L581
L579:
  store i64 33, i64* %ptr_type
  br label %L581
L581:
  %r441 = load i64, i64* %ptr_txt
  %r442 = getelementptr [4 x i8], [4 x i8]* @.str.88, i64 0, i64 0
  %r443 = ptrtoint i8* %r442 to i64
  %r444 = call i64 @_eq(i64 %r441, i64 %r443)
  %r445 = icmp ne i64 %r444, 0
  br i1 %r445, label %L582, label %L584
L582:
  store i64 34, i64* %ptr_type
  br label %L584
L584:
  %r446 = load i64, i64* %ptr_txt
  %r447 = getelementptr [6 x i8], [6 x i8]* @.str.89, i64 0, i64 0
  %r448 = ptrtoint i8* %r447 to i64
  %r449 = call i64 @_eq(i64 %r446, i64 %r448)
  %r450 = icmp ne i64 %r449, 0
  br i1 %r450, label %L585, label %L587
L585:
  store i64 1, i64* %ptr_type
  %r451 = getelementptr [2 x i8], [2 x i8]* @.str.90, i64 0, i64 0
  %r452 = ptrtoint i8* %r451 to i64
  store i64 %r452, i64* %ptr_txt
  br label %L587
L587:
  %r453 = load i64, i64* %ptr_txt
  %r454 = getelementptr [7 x i8], [7 x i8]* @.str.91, i64 0, i64 0
  %r455 = ptrtoint i8* %r454 to i64
  %r456 = call i64 @_eq(i64 %r453, i64 %r455)
  %r457 = icmp ne i64 %r456, 0
  br i1 %r457, label %L588, label %L590
L588:
  store i64 1, i64* %ptr_type
  %r458 = getelementptr [2 x i8], [2 x i8]* @.str.92, i64 0, i64 0
  %r459 = ptrtoint i8* %r458 to i64
  store i64 %r459, i64* %ptr_txt
  br label %L590
L590:
  %r460 = load i64, i64* %ptr_type
  %r461 = load i64, i64* %ptr_txt
  %r462 = call i64 @make_token(i64 %r460, i64 %r461)
  %r463 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r463, i64 %r462)
  br label %L491
L490:
  store i64 0, i64* %ptr_type
  store i64 1, i64* %ptr_adv
  %r464 = load i64, i64* %ptr_c
  %r465 = getelementptr [2 x i8], [2 x i8]* @.str.93, i64 0, i64 0
  %r466 = ptrtoint i8* %r465 to i64
  %r467 = call i64 @_eq(i64 %r464, i64 %r466)
  %r468 = icmp ne i64 %r467, 0
  br i1 %r468, label %L591, label %L593
L591:
  %r469 = load i64, i64* @TOK_LPAREN
  store i64 %r469, i64* %ptr_type
  br label %L593
L593:
  %r470 = load i64, i64* %ptr_c
  %r471 = getelementptr [2 x i8], [2 x i8]* @.str.94, i64 0, i64 0
  %r472 = ptrtoint i8* %r471 to i64
  %r473 = call i64 @_eq(i64 %r470, i64 %r472)
  %r474 = icmp ne i64 %r473, 0
  br i1 %r474, label %L594, label %L596
L594:
  %r475 = load i64, i64* @TOK_RPAREN
  store i64 %r475, i64* %ptr_type
  br label %L596
L596:
  %r476 = load i64, i64* %ptr_c
  %r477 = getelementptr [2 x i8], [2 x i8]* @.str.95, i64 0, i64 0
  %r478 = ptrtoint i8* %r477 to i64
  %r479 = call i64 @_eq(i64 %r476, i64 %r478)
  %r480 = icmp ne i64 %r479, 0
  br i1 %r480, label %L597, label %L599
L597:
  %r481 = load i64, i64* @TOK_LBRACE
  store i64 %r481, i64* %ptr_type
  br label %L599
L599:
  %r482 = load i64, i64* %ptr_c
  %r483 = getelementptr [2 x i8], [2 x i8]* @.str.96, i64 0, i64 0
  %r484 = ptrtoint i8* %r483 to i64
  %r485 = call i64 @_eq(i64 %r482, i64 %r484)
  %r486 = icmp ne i64 %r485, 0
  br i1 %r486, label %L600, label %L602
L600:
  %r487 = load i64, i64* @TOK_RBRACE
  store i64 %r487, i64* %ptr_type
  br label %L602
L602:
  %r488 = load i64, i64* %ptr_c
  %r489 = getelementptr [2 x i8], [2 x i8]* @.str.97, i64 0, i64 0
  %r490 = ptrtoint i8* %r489 to i64
  %r491 = call i64 @_eq(i64 %r488, i64 %r490)
  %r492 = icmp ne i64 %r491, 0
  br i1 %r492, label %L603, label %L605
L603:
  %r493 = load i64, i64* @TOK_LBRACKET
  store i64 %r493, i64* %ptr_type
  br label %L605
L605:
  %r494 = load i64, i64* %ptr_c
  %r495 = getelementptr [2 x i8], [2 x i8]* @.str.98, i64 0, i64 0
  %r496 = ptrtoint i8* %r495 to i64
  %r497 = call i64 @_eq(i64 %r494, i64 %r496)
  %r498 = icmp ne i64 %r497, 0
  br i1 %r498, label %L606, label %L608
L606:
  %r499 = load i64, i64* @TOK_RBRACKET
  store i64 %r499, i64* %ptr_type
  br label %L608
L608:
  %r500 = load i64, i64* %ptr_c
  %r501 = getelementptr [2 x i8], [2 x i8]* @.str.99, i64 0, i64 0
  %r502 = ptrtoint i8* %r501 to i64
  %r503 = call i64 @_eq(i64 %r500, i64 %r502)
  %r504 = icmp ne i64 %r503, 0
  br i1 %r504, label %L609, label %L611
L609:
  %r505 = load i64, i64* @TOK_COLON
  store i64 %r505, i64* %ptr_type
  br label %L611
L611:
  %r506 = load i64, i64* %ptr_c
  %r507 = getelementptr [2 x i8], [2 x i8]* @.str.100, i64 0, i64 0
  %r508 = ptrtoint i8* %r507 to i64
  %r509 = call i64 @_eq(i64 %r506, i64 %r508)
  %r510 = icmp ne i64 %r509, 0
  br i1 %r510, label %L612, label %L614
L612:
  %r511 = load i64, i64* @TOK_CARET
  store i64 %r511, i64* %ptr_type
  br label %L614
L614:
  %r512 = load i64, i64* %ptr_c
  %r513 = getelementptr [2 x i8], [2 x i8]* @.str.101, i64 0, i64 0
  %r514 = ptrtoint i8* %r513 to i64
  %r515 = call i64 @_eq(i64 %r512, i64 %r514)
  %r516 = icmp ne i64 %r515, 0
  br i1 %r516, label %L615, label %L617
L615:
  %r517 = load i64, i64* @TOK_DOT
  store i64 %r517, i64* %ptr_type
  br label %L617
L617:
  %r518 = load i64, i64* %ptr_c
  %r519 = getelementptr [2 x i8], [2 x i8]* @.str.102, i64 0, i64 0
  %r520 = ptrtoint i8* %r519 to i64
  %r521 = call i64 @_eq(i64 %r518, i64 %r520)
  %r522 = icmp ne i64 %r521, 0
  br i1 %r522, label %L618, label %L620
L618:
  %r523 = load i64, i64* @TOK_COMMA
  store i64 %r523, i64* %ptr_type
  br label %L620
L620:
  %r524 = load i64, i64* %ptr_type
  %r525 = call i64 @_eq(i64 %r524, i64 0)
  %r526 = icmp ne i64 %r525, 0
  br i1 %r526, label %L621, label %L623
L621:
  %r527 = load i64, i64* @TOK_OP
  store i64 %r527, i64* %ptr_type
  %r528 = load i64, i64* %ptr_src
  %r529 = load i64, i64* %ptr_i
  %r530 = call i64 @_add(i64 %r529, i64 1)
  %r531 = call i64 @pars(i64 %r528, i64 %r530, i64 1)
  store i64 %r531, i64* %ptr_next
  %r532 = load i64, i64* %ptr_c
  %r533 = getelementptr [2 x i8], [2 x i8]* @.str.103, i64 0, i64 0
  %r534 = ptrtoint i8* %r533 to i64
  %r535 = call i64 @_eq(i64 %r532, i64 %r534)
  %r536 = icmp ne i64 %r535, 0
  br i1 %r536, label %L624, label %L626
L624:
  %r537 = load i64, i64* %ptr_next
  %r538 = getelementptr [2 x i8], [2 x i8]* @.str.104, i64 0, i64 0
  %r539 = ptrtoint i8* %r538 to i64
  %r540 = call i64 @_eq(i64 %r537, i64 %r539)
  %r541 = icmp ne i64 %r540, 0
  br i1 %r541, label %L627, label %L629
L627:
  %r542 = load i64, i64* @TOK_ARROW
  store i64 %r542, i64* %ptr_type
  %r543 = getelementptr [3 x i8], [3 x i8]* @.str.105, i64 0, i64 0
  %r544 = ptrtoint i8* %r543 to i64
  store i64 %r544, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L629
L629:
  br label %L626
L626:
  %r545 = load i64, i64* %ptr_c
  %r546 = getelementptr [2 x i8], [2 x i8]* @.str.106, i64 0, i64 0
  %r547 = ptrtoint i8* %r546 to i64
  %r548 = call i64 @_eq(i64 %r545, i64 %r547)
  %r549 = icmp ne i64 %r548, 0
  br i1 %r549, label %L630, label %L632
L630:
  %r550 = load i64, i64* %ptr_next
  %r551 = getelementptr [2 x i8], [2 x i8]* @.str.107, i64 0, i64 0
  %r552 = ptrtoint i8* %r551 to i64
  %r553 = call i64 @_eq(i64 %r550, i64 %r552)
  %r554 = icmp ne i64 %r553, 0
  br i1 %r554, label %L633, label %L635
L633:
  %r555 = getelementptr [3 x i8], [3 x i8]* @.str.108, i64 0, i64 0
  %r556 = ptrtoint i8* %r555 to i64
  store i64 %r556, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L635
L635:
  br label %L632
L632:
  %r557 = load i64, i64* %ptr_c
  %r558 = getelementptr [2 x i8], [2 x i8]* @.str.109, i64 0, i64 0
  %r559 = ptrtoint i8* %r558 to i64
  %r560 = call i64 @_eq(i64 %r557, i64 %r559)
  %r561 = icmp ne i64 %r560, 0
  br i1 %r561, label %L636, label %L638
L636:
  %r562 = load i64, i64* %ptr_next
  %r563 = getelementptr [2 x i8], [2 x i8]* @.str.110, i64 0, i64 0
  %r564 = ptrtoint i8* %r563 to i64
  %r565 = call i64 @_eq(i64 %r562, i64 %r564)
  %r566 = icmp ne i64 %r565, 0
  br i1 %r566, label %L639, label %L641
L639:
  %r567 = getelementptr [3 x i8], [3 x i8]* @.str.111, i64 0, i64 0
  %r568 = ptrtoint i8* %r567 to i64
  store i64 %r568, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L641
L641:
  br label %L638
L638:
  %r569 = load i64, i64* %ptr_c
  %r570 = getelementptr [2 x i8], [2 x i8]* @.str.112, i64 0, i64 0
  %r571 = ptrtoint i8* %r570 to i64
  %r572 = call i64 @_eq(i64 %r569, i64 %r571)
  %r573 = icmp ne i64 %r572, 0
  br i1 %r573, label %L642, label %L644
L642:
  %r574 = load i64, i64* %ptr_src
  %r575 = load i64, i64* %ptr_i
  %r576 = call i64 @_add(i64 %r575, i64 2)
  %r577 = call i64 @pars(i64 %r574, i64 %r576, i64 1)
  store i64 %r577, i64* %ptr_next2
  %r578 = load i64, i64* %ptr_next
  %r579 = getelementptr [2 x i8], [2 x i8]* @.str.113, i64 0, i64 0
  %r580 = ptrtoint i8* %r579 to i64
  %r581 = call i64 @_eq(i64 %r578, i64 %r580)
  %r582 = icmp ne i64 %r581, 0
  br i1 %r582, label %L645, label %L646
L645:
  %r583 = load i64, i64* %ptr_next2
  %r584 = getelementptr [2 x i8], [2 x i8]* @.str.114, i64 0, i64 0
  %r585 = ptrtoint i8* %r584 to i64
  %r586 = call i64 @_eq(i64 %r583, i64 %r585)
  %r587 = icmp ne i64 %r586, 0
  br i1 %r587, label %L648, label %L649
L648:
  store i64 37, i64* %ptr_type
  %r588 = getelementptr [4 x i8], [4 x i8]* @.str.115, i64 0, i64 0
  %r589 = ptrtoint i8* %r588 to i64
  store i64 %r589, i64* %ptr_c
  store i64 3, i64* %ptr_adv
  br label %L650
L649:
  %r590 = load i64, i64* @TOK_APPEND
  store i64 %r590, i64* %ptr_type
  %r591 = getelementptr [3 x i8], [3 x i8]* @.str.116, i64 0, i64 0
  %r592 = ptrtoint i8* %r591 to i64
  store i64 %r592, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L650
L650:
  br label %L647
L646:
  %r593 = load i64, i64* %ptr_next
  %r594 = getelementptr [2 x i8], [2 x i8]* @.str.117, i64 0, i64 0
  %r595 = ptrtoint i8* %r594 to i64
  %r596 = call i64 @_eq(i64 %r593, i64 %r595)
  %r597 = icmp ne i64 %r596, 0
  br i1 %r597, label %L651, label %L653
L651:
  %r598 = load i64, i64* @TOK_OP
  store i64 %r598, i64* %ptr_type
  %r599 = getelementptr [3 x i8], [3 x i8]* @.str.118, i64 0, i64 0
  %r600 = ptrtoint i8* %r599 to i64
  store i64 %r600, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L653
L653:
  br label %L647
L647:
  br label %L644
L644:
  %r601 = load i64, i64* %ptr_c
  %r602 = getelementptr [2 x i8], [2 x i8]* @.str.119, i64 0, i64 0
  %r603 = ptrtoint i8* %r602 to i64
  %r604 = call i64 @_eq(i64 %r601, i64 %r603)
  %r605 = icmp ne i64 %r604, 0
  br i1 %r605, label %L654, label %L656
L654:
  %r606 = load i64, i64* %ptr_src
  %r607 = load i64, i64* %ptr_i
  %r608 = call i64 @_add(i64 %r607, i64 2)
  %r609 = call i64 @pars(i64 %r606, i64 %r608, i64 1)
  store i64 %r609, i64* %ptr_next2
  %r610 = load i64, i64* %ptr_next
  %r611 = getelementptr [2 x i8], [2 x i8]* @.str.120, i64 0, i64 0
  %r612 = ptrtoint i8* %r611 to i64
  %r613 = call i64 @_eq(i64 %r610, i64 %r612)
  %r614 = icmp ne i64 %r613, 0
  br i1 %r614, label %L657, label %L658
L657:
  %r615 = load i64, i64* %ptr_next2
  %r616 = getelementptr [2 x i8], [2 x i8]* @.str.121, i64 0, i64 0
  %r617 = ptrtoint i8* %r616 to i64
  %r618 = call i64 @_eq(i64 %r615, i64 %r617)
  %r619 = icmp ne i64 %r618, 0
  br i1 %r619, label %L660, label %L661
L660:
  store i64 37, i64* %ptr_type
  %r620 = getelementptr [4 x i8], [4 x i8]* @.str.122, i64 0, i64 0
  %r621 = ptrtoint i8* %r620 to i64
  store i64 %r621, i64* %ptr_c
  store i64 3, i64* %ptr_adv
  br label %L662
L661:
  %r622 = load i64, i64* @TOK_EXTRACT
  store i64 %r622, i64* %ptr_type
  %r623 = getelementptr [3 x i8], [3 x i8]* @.str.123, i64 0, i64 0
  %r624 = ptrtoint i8* %r623 to i64
  store i64 %r624, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L662
L662:
  br label %L659
L658:
  %r625 = load i64, i64* %ptr_next
  %r626 = getelementptr [2 x i8], [2 x i8]* @.str.124, i64 0, i64 0
  %r627 = ptrtoint i8* %r626 to i64
  %r628 = call i64 @_eq(i64 %r625, i64 %r627)
  %r629 = icmp ne i64 %r628, 0
  br i1 %r629, label %L663, label %L665
L663:
  %r630 = load i64, i64* @TOK_OP
  store i64 %r630, i64* %ptr_type
  %r631 = getelementptr [3 x i8], [3 x i8]* @.str.125, i64 0, i64 0
  %r632 = ptrtoint i8* %r631 to i64
  store i64 %r632, i64* %ptr_c
  store i64 2, i64* %ptr_adv
  br label %L665
L665:
  br label %L659
L659:
  br label %L656
L656:
  br label %L623
L623:
  %r633 = load i64, i64* %ptr_type
  %r634 = load i64, i64* %ptr_c
  %r635 = call i64 @make_token(i64 %r633, i64 %r634)
  %r636 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r636, i64 %r635)
  %r637 = load i64, i64* %ptr_i
  %r638 = load i64, i64* %ptr_adv
  %r639 = call i64 @_add(i64 %r637, i64 %r638)
  store i64 %r639, i64* %ptr_i
  br label %L491
L491:
  br label %L440
L440:
  br label %L407
L407:
  br label %L366
L366:
  br label %L363
L363:
  br label %L358
L360:
  %r640 = load i64, i64* @TOK_EOF
  %r641 = getelementptr [4 x i8], [4 x i8]* @.str.126, i64 0, i64 0
  %r642 = ptrtoint i8* %r641 to i64
  %r643 = call i64 @make_token(i64 %r640, i64 %r642)
  %r644 = load i64, i64* %ptr_tokens
  call i64 @_append_poly(i64 %r644, i64 %r643)
  %r645 = load i64, i64* %ptr_tokens
  ret i64 %r645
  ret i64 0
}
define i64 @peek() {
  %r1 = load i64, i64* @p_pos
  %r2 = load i64, i64* @global_tokens
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp sge i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L666, label %L668
L666:
  %r7 = call i64 @_map_new()
  %r8 = getelementptr [5 x i8], [5 x i8]* @.str.127, i64 0, i64 0
  %r9 = ptrtoint i8* %r8 to i64
  %r10 = load i64, i64* @TOK_EOF
  call i64 @_map_set(i64 %r7, i64 %r9, i64 %r10)
  %r11 = getelementptr [5 x i8], [5 x i8]* @.str.128, i64 0, i64 0
  %r12 = ptrtoint i8* %r11 to i64
  %r13 = getelementptr [4 x i8], [4 x i8]* @.str.129, i64 0, i64 0
  %r14 = ptrtoint i8* %r13 to i64
  call i64 @_map_set(i64 %r7, i64 %r12, i64 %r14)
  ret i64 %r7
  br label %L668
L668:
  %r15 = load i64, i64* @global_tokens
  %r16 = load i64, i64* @p_pos
  %r17 = call i64 @_get(i64 %r15, i64 %r16)
  ret i64 %r17
  ret i64 0
}
define i64 @advance() {
  %ptr_t = alloca i64
  %r1 = call i64 @peek()
  store i64 %r1, i64* %ptr_t
  %r2 = load i64, i64* %ptr_t
  %r3 = getelementptr [5 x i8], [5 x i8]* @.str.130, i64 0, i64 0
  %r4 = ptrtoint i8* %r3 to i64
  %r5 = call i64 @_get(i64 %r2, i64 %r4)
  %r6 = load i64, i64* @TOK_EOF
  %r8 = call i64 @_eq(i64 %r5, i64 %r6)
  %r7 = xor i64 %r8, 1
  %r9 = icmp ne i64 %r7, 0
  br i1 %r9, label %L669, label %L671
L669:
  %r10 = load i64, i64* @p_pos
  %r11 = call i64 @_add(i64 %r10, i64 1)
  store i64 %r11, i64* @p_pos
  br label %L671
L671:
  %r12 = load i64, i64* %ptr_t
  ret i64 %r12
  ret i64 0
}
define i64 @consume(i64 %arg_type) {
  %ptr_type = alloca i64
  store i64 %arg_type, i64* %ptr_type
  %ptr_t = alloca i64
  %r1 = call i64 @peek()
  store i64 %r1, i64* %ptr_t
  %r2 = load i64, i64* %ptr_t
  %r3 = getelementptr [5 x i8], [5 x i8]* @.str.131, i64 0, i64 0
  %r4 = ptrtoint i8* %r3 to i64
  %r5 = call i64 @_get(i64 %r2, i64 %r4)
  %r6 = load i64, i64* %ptr_type
  %r7 = call i64 @_eq(i64 %r5, i64 %r6)
  %r8 = icmp ne i64 %r7, 0
  br i1 %r8, label %L672, label %L674
L672:
  %r9 = call i64 @advance()
  ret i64 1
  br label %L674
L674:
  ret i64 0
  ret i64 0
}
define i64 @expect(i64 %arg_type) {
  %ptr_type = alloca i64
  store i64 %arg_type, i64* %ptr_type
  %ptr_t = alloca i64
  %r1 = load i64, i64* %ptr_type
  %r2 = call i64 @consume(i64 %r1)
  %r3 = icmp ne i64 %r2, 0
  br i1 %r3, label %L675, label %L677
L675:
  ret i64 1
  br label %L677
L677:
  %r4 = call i64 @peek()
  store i64 %r4, i64* %ptr_t
  %r5 = getelementptr [21 x i8], [21 x i8]* @.str.132, i64 0, i64 0
  %r6 = ptrtoint i8* %r5 to i64
  %r7 = load i64, i64* %ptr_type
  %r8 = call i64 @int_to_str(i64 %r7)
  %r9 = call i64 @_add(i64 %r6, i64 %r8)
  %r10 = getelementptr [10 x i8], [10 x i8]* @.str.133, i64 0, i64 0
  %r11 = ptrtoint i8* %r10 to i64
  %r12 = call i64 @_add(i64 %r9, i64 %r11)
  %r13 = load i64, i64* %ptr_t
  %r14 = getelementptr [5 x i8], [5 x i8]* @.str.134, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  %r16 = call i64 @_get(i64 %r13, i64 %r15)
  %r17 = call i64 @_add(i64 %r12, i64 %r16)
  %r18 = call i64 @error_report(i64 %r17)
  ret i64 0
  ret i64 0
}
define i64 @parse_primary() {
  %ptr_t = alloca i64
  %ptr_name = alloca i64
  %ptr_args = alloca i64
  %ptr_expr = alloca i64
  %ptr_items = alloca i64
  %ptr_keys = alloca i64
  %ptr_vals = alloca i64
  %ptr_k = alloca i64
  %ptr_v = alloca i64
  %ptr_right = alloca i64
  %r1 = call i64 @peek()
  store i64 %r1, i64* %ptr_t
  %r2 = load i64, i64* @TOK_INT
  %r3 = call i64 @consume(i64 %r2)
  %r4 = icmp ne i64 %r3, 0
  br i1 %r4, label %L678, label %L680
L678:
  %r5 = call i64 @_map_new()
  %r6 = getelementptr [5 x i8], [5 x i8]* @.str.135, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  %r8 = load i64, i64* @EXPR_INT
  call i64 @_map_set(i64 %r5, i64 %r7, i64 %r8)
  %r9 = getelementptr [4 x i8], [4 x i8]* @.str.136, i64 0, i64 0
  %r10 = ptrtoint i8* %r9 to i64
  %r11 = load i64, i64* %ptr_t
  %r12 = getelementptr [5 x i8], [5 x i8]* @.str.137, i64 0, i64 0
  %r13 = ptrtoint i8* %r12 to i64
  %r14 = call i64 @_get(i64 %r11, i64 %r13)
  call i64 @_map_set(i64 %r5, i64 %r10, i64 %r14)
  ret i64 %r5
  br label %L680
L680:
  %r15 = load i64, i64* @TOK_STRING
  %r16 = call i64 @consume(i64 %r15)
  %r17 = icmp ne i64 %r16, 0
  br i1 %r17, label %L681, label %L683
L681:
  %r18 = call i64 @_map_new()
  %r19 = getelementptr [5 x i8], [5 x i8]* @.str.138, i64 0, i64 0
  %r20 = ptrtoint i8* %r19 to i64
  %r21 = load i64, i64* @EXPR_STRING
  call i64 @_map_set(i64 %r18, i64 %r20, i64 %r21)
  %r22 = getelementptr [4 x i8], [4 x i8]* @.str.139, i64 0, i64 0
  %r23 = ptrtoint i8* %r22 to i64
  %r24 = load i64, i64* %ptr_t
  %r25 = getelementptr [5 x i8], [5 x i8]* @.str.140, i64 0, i64 0
  %r26 = ptrtoint i8* %r25 to i64
  %r27 = call i64 @_get(i64 %r24, i64 %r26)
  call i64 @_map_set(i64 %r18, i64 %r23, i64 %r27)
  ret i64 %r18
  br label %L683
L683:
  %r28 = load i64, i64* @TOK_IDENT
  %r29 = call i64 @consume(i64 %r28)
  %r30 = icmp ne i64 %r29, 0
  br i1 %r30, label %L684, label %L686
L684:
  %r31 = load i64, i64* %ptr_t
  %r32 = getelementptr [5 x i8], [5 x i8]* @.str.141, i64 0, i64 0
  %r33 = ptrtoint i8* %r32 to i64
  %r34 = call i64 @_get(i64 %r31, i64 %r33)
  store i64 %r34, i64* %ptr_name
  %r35 = load i64, i64* @TOK_LPAREN
  %r36 = call i64 @consume(i64 %r35)
  %r37 = icmp ne i64 %r36, 0
  br i1 %r37, label %L687, label %L689
L687:
  %r38 = call i64 @_list_new()
  store i64 %r38, i64* %ptr_args
  %r39 = call i64 @peek()
  %r40 = getelementptr [5 x i8], [5 x i8]* @.str.142, i64 0, i64 0
  %r41 = ptrtoint i8* %r40 to i64
  %r42 = call i64 @_get(i64 %r39, i64 %r41)
  %r43 = load i64, i64* @TOK_RPAREN
  %r45 = call i64 @_eq(i64 %r42, i64 %r43)
  %r44 = xor i64 %r45, 1
  %r46 = icmp ne i64 %r44, 0
  br i1 %r46, label %L690, label %L692
L690:
  %r47 = call i64 @parse_expr()
  %r48 = load i64, i64* %ptr_args
  call i64 @_append_poly(i64 %r48, i64 %r47)
  br label %L693
L693:
  %r49 = load i64, i64* @TOK_COMMA
  %r50 = call i64 @consume(i64 %r49)
  %r51 = icmp ne i64 %r50, 0
  br i1 %r51, label %L694, label %L695
L694:
  %r52 = call i64 @parse_expr()
  %r53 = load i64, i64* %ptr_args
  call i64 @_append_poly(i64 %r53, i64 %r52)
  br label %L693
L695:
  br label %L692
L692:
  %r54 = load i64, i64* @TOK_RPAREN
  %r55 = call i64 @expect(i64 %r54)
  %r56 = call i64 @_map_new()
  %r57 = getelementptr [5 x i8], [5 x i8]* @.str.143, i64 0, i64 0
  %r58 = ptrtoint i8* %r57 to i64
  %r59 = load i64, i64* @EXPR_CALL
  call i64 @_map_set(i64 %r56, i64 %r58, i64 %r59)
  %r60 = getelementptr [5 x i8], [5 x i8]* @.str.144, i64 0, i64 0
  %r61 = ptrtoint i8* %r60 to i64
  %r62 = load i64, i64* %ptr_name
  call i64 @_map_set(i64 %r56, i64 %r61, i64 %r62)
  %r63 = getelementptr [5 x i8], [5 x i8]* @.str.145, i64 0, i64 0
  %r64 = ptrtoint i8* %r63 to i64
  %r65 = load i64, i64* %ptr_args
  call i64 @_map_set(i64 %r56, i64 %r64, i64 %r65)
  ret i64 %r56
  br label %L689
L689:
  %r66 = call i64 @_map_new()
  %r67 = getelementptr [5 x i8], [5 x i8]* @.str.146, i64 0, i64 0
  %r68 = ptrtoint i8* %r67 to i64
  %r69 = load i64, i64* @EXPR_VAR
  call i64 @_map_set(i64 %r66, i64 %r68, i64 %r69)
  %r70 = getelementptr [5 x i8], [5 x i8]* @.str.147, i64 0, i64 0
  %r71 = ptrtoint i8* %r70 to i64
  %r72 = load i64, i64* %ptr_name
  call i64 @_map_set(i64 %r66, i64 %r71, i64 %r72)
  ret i64 %r66
  br label %L686
L686:
  %r73 = load i64, i64* @TOK_LPAREN
  %r74 = call i64 @consume(i64 %r73)
  %r75 = icmp ne i64 %r74, 0
  br i1 %r75, label %L696, label %L698
L696:
  %r76 = call i64 @parse_expr()
  store i64 %r76, i64* %ptr_expr
  %r77 = load i64, i64* @TOK_RPAREN
  %r78 = call i64 @expect(i64 %r77)
  %r79 = load i64, i64* %ptr_expr
  ret i64 %r79
  br label %L698
L698:
  %r80 = load i64, i64* @TOK_LBRACKET
  %r81 = call i64 @consume(i64 %r80)
  %r82 = icmp ne i64 %r81, 0
  br i1 %r82, label %L699, label %L701
L699:
  %r83 = call i64 @_list_new()
  store i64 %r83, i64* %ptr_items
  %r84 = call i64 @peek()
  %r85 = getelementptr [5 x i8], [5 x i8]* @.str.148, i64 0, i64 0
  %r86 = ptrtoint i8* %r85 to i64
  %r87 = call i64 @_get(i64 %r84, i64 %r86)
  %r88 = load i64, i64* @TOK_RBRACKET
  %r90 = call i64 @_eq(i64 %r87, i64 %r88)
  %r89 = xor i64 %r90, 1
  %r91 = icmp ne i64 %r89, 0
  br i1 %r91, label %L702, label %L704
L702:
  %r92 = call i64 @parse_expr()
  %r93 = load i64, i64* %ptr_items
  call i64 @_append_poly(i64 %r93, i64 %r92)
  br label %L705
L705:
  %r94 = load i64, i64* @TOK_COMMA
  %r95 = call i64 @consume(i64 %r94)
  %r96 = icmp ne i64 %r95, 0
  br i1 %r96, label %L706, label %L707
L706:
  %r97 = call i64 @parse_expr()
  %r98 = load i64, i64* %ptr_items
  call i64 @_append_poly(i64 %r98, i64 %r97)
  br label %L705
L707:
  br label %L704
L704:
  %r99 = load i64, i64* @TOK_RBRACKET
  %r100 = call i64 @expect(i64 %r99)
  %r101 = call i64 @_map_new()
  %r102 = getelementptr [5 x i8], [5 x i8]* @.str.149, i64 0, i64 0
  %r103 = ptrtoint i8* %r102 to i64
  %r104 = load i64, i64* @EXPR_LIST
  call i64 @_map_set(i64 %r101, i64 %r103, i64 %r104)
  %r105 = getelementptr [6 x i8], [6 x i8]* @.str.150, i64 0, i64 0
  %r106 = ptrtoint i8* %r105 to i64
  %r107 = load i64, i64* %ptr_items
  call i64 @_map_set(i64 %r101, i64 %r106, i64 %r107)
  ret i64 %r101
  br label %L701
L701:
  %r108 = load i64, i64* @TOK_LBRACE
  %r109 = call i64 @consume(i64 %r108)
  %r110 = icmp ne i64 %r109, 0
  br i1 %r110, label %L708, label %L710
L708:
  %r111 = call i64 @_list_new()
  store i64 %r111, i64* %ptr_keys
  %r112 = call i64 @_list_new()
  store i64 %r112, i64* %ptr_vals
  br label %L711
L711:
  %r113 = call i64 @peek()
  %r114 = getelementptr [5 x i8], [5 x i8]* @.str.151, i64 0, i64 0
  %r115 = ptrtoint i8* %r114 to i64
  %r116 = call i64 @_get(i64 %r113, i64 %r115)
  %r117 = load i64, i64* @TOK_RBRACE
  %r119 = call i64 @_eq(i64 %r116, i64 %r117)
  %r118 = xor i64 %r119, 1
  %r120 = icmp ne i64 %r118, 0
  br i1 %r120, label %L712, label %L713
L712:
  %r121 = call i64 @advance()
  store i64 %r121, i64* %ptr_k
  %r122 = load i64, i64* @TOK_COLON
  %r123 = call i64 @expect(i64 %r122)
  %r124 = call i64 @parse_expr()
  store i64 %r124, i64* %ptr_v
  %r125 = load i64, i64* %ptr_k
  %r126 = getelementptr [5 x i8], [5 x i8]* @.str.152, i64 0, i64 0
  %r127 = ptrtoint i8* %r126 to i64
  %r128 = call i64 @_get(i64 %r125, i64 %r127)
  %r129 = load i64, i64* %ptr_keys
  call i64 @_append_poly(i64 %r129, i64 %r128)
  %r130 = load i64, i64* %ptr_v
  %r131 = load i64, i64* %ptr_vals
  call i64 @_append_poly(i64 %r131, i64 %r130)
  %r132 = load i64, i64* @TOK_COMMA
  %r133 = call i64 @consume(i64 %r132)
  br label %L711
L713:
  %r134 = load i64, i64* @TOK_RBRACE
  %r135 = call i64 @expect(i64 %r134)
  %r136 = call i64 @_map_new()
  %r137 = getelementptr [5 x i8], [5 x i8]* @.str.153, i64 0, i64 0
  %r138 = ptrtoint i8* %r137 to i64
  %r139 = load i64, i64* @EXPR_MAP
  call i64 @_map_set(i64 %r136, i64 %r138, i64 %r139)
  %r140 = getelementptr [5 x i8], [5 x i8]* @.str.154, i64 0, i64 0
  %r141 = ptrtoint i8* %r140 to i64
  %r142 = load i64, i64* %ptr_keys
  call i64 @_map_set(i64 %r136, i64 %r141, i64 %r142)
  %r143 = getelementptr [5 x i8], [5 x i8]* @.str.155, i64 0, i64 0
  %r144 = ptrtoint i8* %r143 to i64
  %r145 = load i64, i64* %ptr_vals
  call i64 @_map_set(i64 %r136, i64 %r144, i64 %r145)
  ret i64 %r136
  br label %L710
L710:
  %r146 = load i64, i64* %ptr_t
  %r147 = getelementptr [5 x i8], [5 x i8]* @.str.157, i64 0, i64 0
  %r148 = ptrtoint i8* %r147 to i64
  %r149 = call i64 @_get(i64 %r146, i64 %r148)
  %r150 = load i64, i64* @TOK_OP
  %r151 = call i64 @_eq(i64 %r149, i64 %r150)
  store i64 0, i64* @.sc.156
  %r153 = icmp ne i64 %r151, 0
  br i1 %r153, label %L714, label %L715
L714:
  %r154 = load i64, i64* %ptr_t
  %r155 = getelementptr [5 x i8], [5 x i8]* @.str.158, i64 0, i64 0
  %r156 = ptrtoint i8* %r155 to i64
  %r157 = call i64 @_get(i64 %r154, i64 %r156)
  %r158 = getelementptr [2 x i8], [2 x i8]* @.str.159, i64 0, i64 0
  %r159 = ptrtoint i8* %r158 to i64
  %r160 = call i64 @_eq(i64 %r157, i64 %r159)
  %r161 = icmp ne i64 %r160, 0
  %r162 = zext i1 %r161 to i64
  store i64 %r162, i64* @.sc.156
  br label %L715
L715:
  %r152 = load i64, i64* @.sc.156
  %r163 = icmp ne i64 %r152, 0
  br i1 %r163, label %L716, label %L718
L716:
  %r164 = call i64 @advance()
  %r165 = call i64 @parse_primary()
  store i64 %r165, i64* %ptr_right
  %r166 = call i64 @_map_new()
  %r167 = getelementptr [5 x i8], [5 x i8]* @.str.160, i64 0, i64 0
  %r168 = ptrtoint i8* %r167 to i64
  %r169 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r166, i64 %r168, i64 %r169)
  %r170 = getelementptr [3 x i8], [3 x i8]* @.str.161, i64 0, i64 0
  %r171 = ptrtoint i8* %r170 to i64
  %r172 = getelementptr [2 x i8], [2 x i8]* @.str.162, i64 0, i64 0
  %r173 = ptrtoint i8* %r172 to i64
  call i64 @_map_set(i64 %r166, i64 %r171, i64 %r173)
  %r174 = getelementptr [5 x i8], [5 x i8]* @.str.163, i64 0, i64 0
  %r175 = ptrtoint i8* %r174 to i64
  %r176 = call i64 @_map_new()
  %r177 = getelementptr [5 x i8], [5 x i8]* @.str.164, i64 0, i64 0
  %r178 = ptrtoint i8* %r177 to i64
  %r179 = load i64, i64* @EXPR_INT
  call i64 @_map_set(i64 %r176, i64 %r178, i64 %r179)
  %r180 = getelementptr [4 x i8], [4 x i8]* @.str.165, i64 0, i64 0
  %r181 = ptrtoint i8* %r180 to i64
  %r182 = getelementptr [2 x i8], [2 x i8]* @.str.166, i64 0, i64 0
  %r183 = ptrtoint i8* %r182 to i64
  call i64 @_map_set(i64 %r176, i64 %r181, i64 %r183)
  call i64 @_map_set(i64 %r166, i64 %r175, i64 %r176)
  %r184 = getelementptr [6 x i8], [6 x i8]* @.str.167, i64 0, i64 0
  %r185 = ptrtoint i8* %r184 to i64
  %r186 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r166, i64 %r185, i64 %r186)
  ret i64 %r166
  br label %L718
L718:
  %r187 = load i64, i64* %ptr_t
  %r188 = getelementptr [5 x i8], [5 x i8]* @.str.169, i64 0, i64 0
  %r189 = ptrtoint i8* %r188 to i64
  %r190 = call i64 @_get(i64 %r187, i64 %r189)
  %r191 = load i64, i64* @TOK_OP
  %r192 = call i64 @_eq(i64 %r190, i64 %r191)
  store i64 0, i64* @.sc.168
  %r194 = icmp ne i64 %r192, 0
  br i1 %r194, label %L719, label %L720
L719:
  %r195 = load i64, i64* %ptr_t
  %r196 = getelementptr [5 x i8], [5 x i8]* @.str.170, i64 0, i64 0
  %r197 = ptrtoint i8* %r196 to i64
  %r198 = call i64 @_get(i64 %r195, i64 %r197)
  %r199 = getelementptr [2 x i8], [2 x i8]* @.str.171, i64 0, i64 0
  %r200 = ptrtoint i8* %r199 to i64
  %r201 = call i64 @_eq(i64 %r198, i64 %r200)
  %r202 = icmp ne i64 %r201, 0
  %r203 = zext i1 %r202 to i64
  store i64 %r203, i64* @.sc.168
  br label %L720
L720:
  %r193 = load i64, i64* @.sc.168
  %r204 = icmp ne i64 %r193, 0
  br i1 %r204, label %L721, label %L723
L721:
  %r205 = call i64 @advance()
  %r206 = call i64 @parse_primary()
  store i64 %r206, i64* %ptr_right
  %r207 = call i64 @_map_new()
  %r208 = getelementptr [5 x i8], [5 x i8]* @.str.172, i64 0, i64 0
  %r209 = ptrtoint i8* %r208 to i64
  %r210 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r207, i64 %r209, i64 %r210)
  %r211 = getelementptr [3 x i8], [3 x i8]* @.str.173, i64 0, i64 0
  %r212 = ptrtoint i8* %r211 to i64
  %r213 = getelementptr [3 x i8], [3 x i8]* @.str.174, i64 0, i64 0
  %r214 = ptrtoint i8* %r213 to i64
  call i64 @_map_set(i64 %r207, i64 %r212, i64 %r214)
  %r215 = getelementptr [5 x i8], [5 x i8]* @.str.175, i64 0, i64 0
  %r216 = ptrtoint i8* %r215 to i64
  %r217 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r207, i64 %r216, i64 %r217)
  %r218 = getelementptr [6 x i8], [6 x i8]* @.str.176, i64 0, i64 0
  %r219 = ptrtoint i8* %r218 to i64
  %r220 = call i64 @_map_new()
  %r221 = getelementptr [5 x i8], [5 x i8]* @.str.177, i64 0, i64 0
  %r222 = ptrtoint i8* %r221 to i64
  %r223 = load i64, i64* @EXPR_INT
  call i64 @_map_set(i64 %r220, i64 %r222, i64 %r223)
  %r224 = getelementptr [4 x i8], [4 x i8]* @.str.178, i64 0, i64 0
  %r225 = ptrtoint i8* %r224 to i64
  %r226 = getelementptr [2 x i8], [2 x i8]* @.str.179, i64 0, i64 0
  %r227 = ptrtoint i8* %r226 to i64
  call i64 @_map_set(i64 %r220, i64 %r225, i64 %r227)
  call i64 @_map_set(i64 %r207, i64 %r219, i64 %r220)
  ret i64 %r207
  br label %L723
L723:
  %r228 = load i64, i64* %ptr_t
  %r229 = getelementptr [5 x i8], [5 x i8]* @.str.180, i64 0, i64 0
  %r230 = ptrtoint i8* %r229 to i64
  %r231 = call i64 @_get(i64 %r228, i64 %r230)
  %r232 = load i64, i64* @TOK_EOF
  %r234 = call i64 @_eq(i64 %r231, i64 %r232)
  %r233 = xor i64 %r234, 1
  %r235 = icmp ne i64 %r233, 0
  br i1 %r235, label %L724, label %L726
L724:
  %r236 = call i64 @advance()
  br label %L726
L726:
  %r237 = getelementptr [19 x i8], [19 x i8]* @.str.181, i64 0, i64 0
  %r238 = ptrtoint i8* %r237 to i64
  %r239 = load i64, i64* %ptr_t
  %r240 = getelementptr [5 x i8], [5 x i8]* @.str.182, i64 0, i64 0
  %r241 = ptrtoint i8* %r240 to i64
  %r242 = call i64 @_get(i64 %r239, i64 %r241)
  %r243 = call i64 @_add(i64 %r238, i64 %r242)
  %r244 = call i64 @error_report(i64 %r243)
  %r245 = call i64 @_map_new()
  %r246 = getelementptr [5 x i8], [5 x i8]* @.str.183, i64 0, i64 0
  %r247 = ptrtoint i8* %r246 to i64
  %r248 = load i64, i64* @EXPR_INT
  call i64 @_map_set(i64 %r245, i64 %r247, i64 %r248)
  %r249 = getelementptr [4 x i8], [4 x i8]* @.str.184, i64 0, i64 0
  %r250 = ptrtoint i8* %r249 to i64
  %r251 = getelementptr [2 x i8], [2 x i8]* @.str.185, i64 0, i64 0
  %r252 = ptrtoint i8* %r251 to i64
  call i64 @_map_set(i64 %r245, i64 %r250, i64 %r252)
  ret i64 %r245
  ret i64 0
}
define i64 @parse_postfix() {
  %ptr_expr = alloca i64
  %ptr_running = alloca i64
  %ptr_idx = alloca i64
  %ptr_t = alloca i64
  %r1 = call i64 @parse_primary()
  store i64 %r1, i64* %ptr_expr
  store i64 1, i64* %ptr_running
  br label %L727
L727:
  %r2 = load i64, i64* %ptr_running
  %r3 = icmp ne i64 %r2, 0
  br i1 %r3, label %L728, label %L729
L728:
  %r4 = load i64, i64* @TOK_LBRACKET
  %r5 = call i64 @consume(i64 %r4)
  %r6 = icmp ne i64 %r5, 0
  br i1 %r6, label %L730, label %L731
L730:
  %r7 = call i64 @parse_expr()
  store i64 %r7, i64* %ptr_idx
  %r8 = load i64, i64* @TOK_RBRACKET
  %r9 = call i64 @expect(i64 %r8)
  %r10 = call i64 @_map_new()
  %r11 = getelementptr [5 x i8], [5 x i8]* @.str.186, i64 0, i64 0
  %r12 = ptrtoint i8* %r11 to i64
  %r13 = load i64, i64* @EXPR_INDEX
  call i64 @_map_set(i64 %r10, i64 %r12, i64 %r13)
  %r14 = getelementptr [4 x i8], [4 x i8]* @.str.187, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  %r16 = load i64, i64* %ptr_expr
  call i64 @_map_set(i64 %r10, i64 %r15, i64 %r16)
  %r17 = getelementptr [4 x i8], [4 x i8]* @.str.188, i64 0, i64 0
  %r18 = ptrtoint i8* %r17 to i64
  %r19 = load i64, i64* %ptr_idx
  call i64 @_map_set(i64 %r10, i64 %r18, i64 %r19)
  store i64 %r10, i64* %ptr_expr
  br label %L732
L731:
  %r20 = load i64, i64* @TOK_DOT
  %r21 = call i64 @consume(i64 %r20)
  %r22 = icmp ne i64 %r21, 0
  br i1 %r22, label %L733, label %L734
L733:
  %r23 = call i64 @advance()
  store i64 %r23, i64* %ptr_t
  %r24 = call i64 @_map_new()
  %r25 = getelementptr [5 x i8], [5 x i8]* @.str.189, i64 0, i64 0
  %r26 = ptrtoint i8* %r25 to i64
  %r27 = load i64, i64* @EXPR_GET
  call i64 @_map_set(i64 %r24, i64 %r26, i64 %r27)
  %r28 = getelementptr [4 x i8], [4 x i8]* @.str.190, i64 0, i64 0
  %r29 = ptrtoint i8* %r28 to i64
  %r30 = load i64, i64* %ptr_expr
  call i64 @_map_set(i64 %r24, i64 %r29, i64 %r30)
  %r31 = getelementptr [5 x i8], [5 x i8]* @.str.191, i64 0, i64 0
  %r32 = ptrtoint i8* %r31 to i64
  %r33 = load i64, i64* %ptr_t
  %r34 = getelementptr [5 x i8], [5 x i8]* @.str.192, i64 0, i64 0
  %r35 = ptrtoint i8* %r34 to i64
  %r36 = call i64 @_get(i64 %r33, i64 %r35)
  call i64 @_map_set(i64 %r24, i64 %r32, i64 %r36)
  store i64 %r24, i64* %ptr_expr
  br label %L735
L734:
  store i64 0, i64* %ptr_running
  br label %L735
L735:
  br label %L732
L732:
  br label %L727
L729:
  %r37 = load i64, i64* %ptr_expr
  ret i64 %r37
  ret i64 0
}
define i64 @parse_term() {
  %ptr_left = alloca i64
  %ptr_t = alloca i64
  %ptr_running = alloca i64
  %ptr_is_op = alloca i64
  %ptr_op = alloca i64
  %ptr_right = alloca i64
  %r1 = call i64 @parse_postfix()
  store i64 %r1, i64* %ptr_left
  %r2 = call i64 @peek()
  store i64 %r2, i64* %ptr_t
  store i64 1, i64* %ptr_running
  br label %L736
L736:
  %r3 = load i64, i64* %ptr_running
  %r4 = icmp ne i64 %r3, 0
  br i1 %r4, label %L737, label %L738
L737:
  store i64 0, i64* %ptr_is_op
  %r5 = load i64, i64* %ptr_t
  %r6 = getelementptr [5 x i8], [5 x i8]* @.str.193, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  %r8 = call i64 @_get(i64 %r5, i64 %r7)
  %r9 = load i64, i64* @TOK_OP
  %r10 = call i64 @_eq(i64 %r8, i64 %r9)
  %r11 = icmp ne i64 %r10, 0
  br i1 %r11, label %L739, label %L741
L739:
  %r12 = load i64, i64* %ptr_t
  %r13 = getelementptr [5 x i8], [5 x i8]* @.str.194, i64 0, i64 0
  %r14 = ptrtoint i8* %r13 to i64
  %r15 = call i64 @_get(i64 %r12, i64 %r14)
  store i64 %r15, i64* %ptr_op
  %r16 = load i64, i64* %ptr_op
  %r17 = getelementptr [2 x i8], [2 x i8]* @.str.195, i64 0, i64 0
  %r18 = ptrtoint i8* %r17 to i64
  %r19 = call i64 @_eq(i64 %r16, i64 %r18)
  %r20 = icmp ne i64 %r19, 0
  br i1 %r20, label %L742, label %L744
L742:
  store i64 1, i64* %ptr_is_op
  br label %L744
L744:
  %r21 = load i64, i64* %ptr_op
  %r22 = getelementptr [2 x i8], [2 x i8]* @.str.196, i64 0, i64 0
  %r23 = ptrtoint i8* %r22 to i64
  %r24 = call i64 @_eq(i64 %r21, i64 %r23)
  %r25 = icmp ne i64 %r24, 0
  br i1 %r25, label %L745, label %L747
L745:
  store i64 1, i64* %ptr_is_op
  br label %L747
L747:
  %r26 = load i64, i64* %ptr_op
  %r27 = getelementptr [2 x i8], [2 x i8]* @.str.197, i64 0, i64 0
  %r28 = ptrtoint i8* %r27 to i64
  %r29 = call i64 @_eq(i64 %r26, i64 %r28)
  %r30 = icmp ne i64 %r29, 0
  br i1 %r30, label %L748, label %L750
L748:
  store i64 1, i64* %ptr_is_op
  br label %L750
L750:
  br label %L741
L741:
  %r31 = load i64, i64* %ptr_is_op
  %r32 = icmp ne i64 %r31, 0
  br i1 %r32, label %L751, label %L752
L751:
  %r33 = load i64, i64* %ptr_t
  %r34 = getelementptr [5 x i8], [5 x i8]* @.str.198, i64 0, i64 0
  %r35 = ptrtoint i8* %r34 to i64
  %r36 = call i64 @_get(i64 %r33, i64 %r35)
  store i64 %r36, i64* %ptr_op
  %r37 = call i64 @advance()
  %r38 = call i64 @parse_postfix()
  store i64 %r38, i64* %ptr_right
  %r39 = call i64 @_map_new()
  %r40 = getelementptr [5 x i8], [5 x i8]* @.str.199, i64 0, i64 0
  %r41 = ptrtoint i8* %r40 to i64
  %r42 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r39, i64 %r41, i64 %r42)
  %r43 = getelementptr [3 x i8], [3 x i8]* @.str.200, i64 0, i64 0
  %r44 = ptrtoint i8* %r43 to i64
  %r45 = load i64, i64* %ptr_op
  call i64 @_map_set(i64 %r39, i64 %r44, i64 %r45)
  %r46 = getelementptr [5 x i8], [5 x i8]* @.str.201, i64 0, i64 0
  %r47 = ptrtoint i8* %r46 to i64
  %r48 = load i64, i64* %ptr_left
  call i64 @_map_set(i64 %r39, i64 %r47, i64 %r48)
  %r49 = getelementptr [6 x i8], [6 x i8]* @.str.202, i64 0, i64 0
  %r50 = ptrtoint i8* %r49 to i64
  %r51 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r39, i64 %r50, i64 %r51)
  store i64 %r39, i64* %ptr_left
  %r52 = call i64 @peek()
  store i64 %r52, i64* %ptr_t
  br label %L753
L752:
  store i64 0, i64* %ptr_running
  br label %L753
L753:
  br label %L736
L738:
  %r53 = load i64, i64* %ptr_left
  ret i64 %r53
  ret i64 0
}
define i64 @parse_math() {
  %ptr_left = alloca i64
  %ptr_t = alloca i64
  %ptr_running = alloca i64
  %ptr_is_op = alloca i64
  %ptr_op = alloca i64
  %ptr_right = alloca i64
  %r1 = call i64 @parse_term()
  store i64 %r1, i64* %ptr_left
  %r2 = call i64 @peek()
  store i64 %r2, i64* %ptr_t
  store i64 1, i64* %ptr_running
  br label %L754
L754:
  %r3 = load i64, i64* %ptr_running
  %r4 = icmp ne i64 %r3, 0
  br i1 %r4, label %L755, label %L756
L755:
  store i64 0, i64* %ptr_is_op
  %r5 = load i64, i64* %ptr_t
  %r6 = getelementptr [5 x i8], [5 x i8]* @.str.203, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  %r8 = call i64 @_get(i64 %r5, i64 %r7)
  %r9 = load i64, i64* @TOK_OP
  %r10 = call i64 @_eq(i64 %r8, i64 %r9)
  %r11 = icmp ne i64 %r10, 0
  br i1 %r11, label %L757, label %L759
L757:
  %r12 = load i64, i64* %ptr_t
  %r13 = getelementptr [5 x i8], [5 x i8]* @.str.204, i64 0, i64 0
  %r14 = ptrtoint i8* %r13 to i64
  %r15 = call i64 @_get(i64 %r12, i64 %r14)
  store i64 %r15, i64* %ptr_op
  %r16 = load i64, i64* %ptr_op
  %r17 = getelementptr [2 x i8], [2 x i8]* @.str.205, i64 0, i64 0
  %r18 = ptrtoint i8* %r17 to i64
  %r19 = call i64 @_eq(i64 %r16, i64 %r18)
  %r20 = icmp ne i64 %r19, 0
  br i1 %r20, label %L760, label %L762
L760:
  store i64 1, i64* %ptr_is_op
  br label %L762
L762:
  %r21 = load i64, i64* %ptr_op
  %r22 = getelementptr [2 x i8], [2 x i8]* @.str.206, i64 0, i64 0
  %r23 = ptrtoint i8* %r22 to i64
  %r24 = call i64 @_eq(i64 %r21, i64 %r23)
  %r25 = icmp ne i64 %r24, 0
  br i1 %r25, label %L763, label %L765
L763:
  store i64 1, i64* %ptr_is_op
  br label %L765
L765:
  br label %L759
L759:
  %r26 = load i64, i64* %ptr_is_op
  %r27 = icmp ne i64 %r26, 0
  br i1 %r27, label %L766, label %L767
L766:
  %r28 = load i64, i64* %ptr_t
  %r29 = getelementptr [5 x i8], [5 x i8]* @.str.207, i64 0, i64 0
  %r30 = ptrtoint i8* %r29 to i64
  %r31 = call i64 @_get(i64 %r28, i64 %r30)
  store i64 %r31, i64* %ptr_op
  %r32 = call i64 @advance()
  %r33 = call i64 @parse_term()
  store i64 %r33, i64* %ptr_right
  %r34 = call i64 @_map_new()
  %r35 = getelementptr [5 x i8], [5 x i8]* @.str.208, i64 0, i64 0
  %r36 = ptrtoint i8* %r35 to i64
  %r37 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r34, i64 %r36, i64 %r37)
  %r38 = getelementptr [3 x i8], [3 x i8]* @.str.209, i64 0, i64 0
  %r39 = ptrtoint i8* %r38 to i64
  %r40 = load i64, i64* %ptr_op
  call i64 @_map_set(i64 %r34, i64 %r39, i64 %r40)
  %r41 = getelementptr [5 x i8], [5 x i8]* @.str.210, i64 0, i64 0
  %r42 = ptrtoint i8* %r41 to i64
  %r43 = load i64, i64* %ptr_left
  call i64 @_map_set(i64 %r34, i64 %r42, i64 %r43)
  %r44 = getelementptr [6 x i8], [6 x i8]* @.str.211, i64 0, i64 0
  %r45 = ptrtoint i8* %r44 to i64
  %r46 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r34, i64 %r45, i64 %r46)
  store i64 %r34, i64* %ptr_left
  %r47 = call i64 @peek()
  store i64 %r47, i64* %ptr_t
  br label %L768
L767:
  store i64 0, i64* %ptr_running
  br label %L768
L768:
  br label %L754
L756:
  %r48 = load i64, i64* %ptr_left
  ret i64 %r48
  ret i64 0
}
define i64 @parse_bitwise() {
  %ptr_left = alloca i64
  %ptr_t = alloca i64
  %ptr_running = alloca i64
  %ptr_is_op = alloca i64
  %ptr_op = alloca i64
  %ptr_right = alloca i64
  %r1 = call i64 @parse_math()
  store i64 %r1, i64* %ptr_left
  %r2 = call i64 @peek()
  store i64 %r2, i64* %ptr_t
  store i64 1, i64* %ptr_running
  br label %L769
L769:
  %r3 = load i64, i64* %ptr_running
  %r4 = icmp ne i64 %r3, 0
  br i1 %r4, label %L770, label %L771
L770:
  store i64 0, i64* %ptr_is_op
  %r5 = load i64, i64* %ptr_t
  %r6 = getelementptr [5 x i8], [5 x i8]* @.str.212, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  %r8 = call i64 @_get(i64 %r5, i64 %r7)
  store i64 %r8, i64* %ptr_op
  %r9 = load i64, i64* %ptr_t
  %r10 = getelementptr [5 x i8], [5 x i8]* @.str.213, i64 0, i64 0
  %r11 = ptrtoint i8* %r10 to i64
  %r12 = call i64 @_get(i64 %r9, i64 %r11)
  %r13 = load i64, i64* @TOK_OP
  %r14 = call i64 @_eq(i64 %r12, i64 %r13)
  %r15 = icmp ne i64 %r14, 0
  br i1 %r15, label %L772, label %L774
L772:
  %r16 = load i64, i64* %ptr_op
  %r17 = getelementptr [2 x i8], [2 x i8]* @.str.214, i64 0, i64 0
  %r18 = ptrtoint i8* %r17 to i64
  %r19 = call i64 @_eq(i64 %r16, i64 %r18)
  %r20 = icmp ne i64 %r19, 0
  br i1 %r20, label %L775, label %L777
L775:
  store i64 1, i64* %ptr_is_op
  br label %L777
L777:
  %r21 = load i64, i64* %ptr_op
  %r22 = getelementptr [2 x i8], [2 x i8]* @.str.215, i64 0, i64 0
  %r23 = ptrtoint i8* %r22 to i64
  %r24 = call i64 @_eq(i64 %r21, i64 %r23)
  %r25 = icmp ne i64 %r24, 0
  br i1 %r25, label %L778, label %L780
L778:
  store i64 1, i64* %ptr_is_op
  br label %L780
L780:
  %r26 = load i64, i64* %ptr_op
  %r27 = getelementptr [2 x i8], [2 x i8]* @.str.216, i64 0, i64 0
  %r28 = ptrtoint i8* %r27 to i64
  %r29 = call i64 @_eq(i64 %r26, i64 %r28)
  %r30 = icmp ne i64 %r29, 0
  br i1 %r30, label %L781, label %L783
L781:
  store i64 1, i64* %ptr_is_op
  br label %L783
L783:
  %r31 = load i64, i64* %ptr_op
  %r32 = getelementptr [4 x i8], [4 x i8]* @.str.217, i64 0, i64 0
  %r33 = ptrtoint i8* %r32 to i64
  %r34 = call i64 @_eq(i64 %r31, i64 %r33)
  %r35 = icmp ne i64 %r34, 0
  br i1 %r35, label %L784, label %L786
L784:
  store i64 1, i64* %ptr_is_op
  br label %L786
L786:
  %r36 = load i64, i64* %ptr_op
  %r37 = getelementptr [4 x i8], [4 x i8]* @.str.218, i64 0, i64 0
  %r38 = ptrtoint i8* %r37 to i64
  %r39 = call i64 @_eq(i64 %r36, i64 %r38)
  %r40 = icmp ne i64 %r39, 0
  br i1 %r40, label %L787, label %L789
L787:
  store i64 1, i64* %ptr_is_op
  br label %L789
L789:
  br label %L774
L774:
  %r41 = load i64, i64* %ptr_t
  %r42 = getelementptr [5 x i8], [5 x i8]* @.str.219, i64 0, i64 0
  %r43 = ptrtoint i8* %r42 to i64
  %r44 = call i64 @_get(i64 %r41, i64 %r43)
  %r45 = load i64, i64* @TOK_IDENT
  %r46 = call i64 @_eq(i64 %r44, i64 %r45)
  %r47 = icmp ne i64 %r46, 0
  br i1 %r47, label %L790, label %L792
L790:
  %r48 = load i64, i64* %ptr_op
  %r49 = getelementptr [4 x i8], [4 x i8]* @.str.220, i64 0, i64 0
  %r50 = ptrtoint i8* %r49 to i64
  %r51 = call i64 @_eq(i64 %r48, i64 %r50)
  %r52 = icmp ne i64 %r51, 0
  br i1 %r52, label %L793, label %L795
L793:
  store i64 1, i64* %ptr_is_op
  %r53 = getelementptr [2 x i8], [2 x i8]* @.str.221, i64 0, i64 0
  %r54 = ptrtoint i8* %r53 to i64
  store i64 %r54, i64* %ptr_op
  br label %L795
L795:
  br label %L792
L792:
  %r55 = load i64, i64* %ptr_is_op
  %r56 = icmp ne i64 %r55, 0
  br i1 %r56, label %L796, label %L797
L796:
  %r57 = call i64 @advance()
  %r58 = call i64 @parse_math()
  store i64 %r58, i64* %ptr_right
  %r59 = call i64 @_map_new()
  %r60 = getelementptr [5 x i8], [5 x i8]* @.str.222, i64 0, i64 0
  %r61 = ptrtoint i8* %r60 to i64
  %r62 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r59, i64 %r61, i64 %r62)
  %r63 = getelementptr [3 x i8], [3 x i8]* @.str.223, i64 0, i64 0
  %r64 = ptrtoint i8* %r63 to i64
  %r65 = load i64, i64* %ptr_op
  call i64 @_map_set(i64 %r59, i64 %r64, i64 %r65)
  %r66 = getelementptr [5 x i8], [5 x i8]* @.str.224, i64 0, i64 0
  %r67 = ptrtoint i8* %r66 to i64
  %r68 = load i64, i64* %ptr_left
  call i64 @_map_set(i64 %r59, i64 %r67, i64 %r68)
  %r69 = getelementptr [6 x i8], [6 x i8]* @.str.225, i64 0, i64 0
  %r70 = ptrtoint i8* %r69 to i64
  %r71 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r59, i64 %r70, i64 %r71)
  store i64 %r59, i64* %ptr_left
  %r72 = call i64 @peek()
  store i64 %r72, i64* %ptr_t
  br label %L798
L797:
  store i64 0, i64* %ptr_running
  br label %L798
L798:
  br label %L769
L771:
  %r73 = load i64, i64* %ptr_left
  ret i64 %r73
  ret i64 0
}
define i64 @parse_cmp() {
  %ptr_left = alloca i64
  %ptr_t = alloca i64
  %ptr_running = alloca i64
  %ptr_is_op = alloca i64
  %ptr_op = alloca i64
  %ptr_right = alloca i64
  %r1 = call i64 @parse_bitwise()
  store i64 %r1, i64* %ptr_left
  %r2 = call i64 @peek()
  store i64 %r2, i64* %ptr_t
  store i64 1, i64* %ptr_running
  br label %L799
L799:
  %r3 = load i64, i64* %ptr_running
  %r4 = icmp ne i64 %r3, 0
  br i1 %r4, label %L800, label %L801
L800:
  store i64 0, i64* %ptr_is_op
  %r5 = load i64, i64* %ptr_t
  %r6 = getelementptr [5 x i8], [5 x i8]* @.str.226, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  %r8 = call i64 @_get(i64 %r5, i64 %r7)
  %r9 = load i64, i64* @TOK_OP
  %r10 = call i64 @_eq(i64 %r8, i64 %r9)
  %r11 = icmp ne i64 %r10, 0
  br i1 %r11, label %L802, label %L804
L802:
  %r12 = load i64, i64* %ptr_t
  %r13 = getelementptr [5 x i8], [5 x i8]* @.str.227, i64 0, i64 0
  %r14 = ptrtoint i8* %r13 to i64
  %r15 = call i64 @_get(i64 %r12, i64 %r14)
  store i64 %r15, i64* %ptr_op
  %r16 = load i64, i64* %ptr_op
  %r17 = getelementptr [3 x i8], [3 x i8]* @.str.228, i64 0, i64 0
  %r18 = ptrtoint i8* %r17 to i64
  %r19 = call i64 @_eq(i64 %r16, i64 %r18)
  %r20 = icmp ne i64 %r19, 0
  br i1 %r20, label %L805, label %L807
L805:
  store i64 1, i64* %ptr_is_op
  br label %L807
L807:
  %r21 = load i64, i64* %ptr_op
  %r22 = getelementptr [3 x i8], [3 x i8]* @.str.229, i64 0, i64 0
  %r23 = ptrtoint i8* %r22 to i64
  %r24 = call i64 @_eq(i64 %r21, i64 %r23)
  %r25 = icmp ne i64 %r24, 0
  br i1 %r25, label %L808, label %L810
L808:
  store i64 1, i64* %ptr_is_op
  br label %L810
L810:
  %r26 = load i64, i64* %ptr_op
  %r27 = getelementptr [2 x i8], [2 x i8]* @.str.230, i64 0, i64 0
  %r28 = ptrtoint i8* %r27 to i64
  %r29 = call i64 @_eq(i64 %r26, i64 %r28)
  %r30 = icmp ne i64 %r29, 0
  br i1 %r30, label %L811, label %L813
L811:
  store i64 1, i64* %ptr_is_op
  br label %L813
L813:
  %r31 = load i64, i64* %ptr_op
  %r32 = getelementptr [2 x i8], [2 x i8]* @.str.231, i64 0, i64 0
  %r33 = ptrtoint i8* %r32 to i64
  %r34 = call i64 @_eq(i64 %r31, i64 %r33)
  %r35 = icmp ne i64 %r34, 0
  br i1 %r35, label %L814, label %L816
L814:
  store i64 1, i64* %ptr_is_op
  br label %L816
L816:
  %r36 = load i64, i64* %ptr_op
  %r37 = getelementptr [3 x i8], [3 x i8]* @.str.232, i64 0, i64 0
  %r38 = ptrtoint i8* %r37 to i64
  %r39 = call i64 @_eq(i64 %r36, i64 %r38)
  %r40 = icmp ne i64 %r39, 0
  br i1 %r40, label %L817, label %L819
L817:
  store i64 1, i64* %ptr_is_op
  br label %L819
L819:
  %r41 = load i64, i64* %ptr_op
  %r42 = getelementptr [3 x i8], [3 x i8]* @.str.233, i64 0, i64 0
  %r43 = ptrtoint i8* %r42 to i64
  %r44 = call i64 @_eq(i64 %r41, i64 %r43)
  %r45 = icmp ne i64 %r44, 0
  br i1 %r45, label %L820, label %L822
L820:
  store i64 1, i64* %ptr_is_op
  br label %L822
L822:
  br label %L804
L804:
  %r46 = load i64, i64* %ptr_is_op
  %r47 = icmp ne i64 %r46, 0
  br i1 %r47, label %L823, label %L824
L823:
  %r48 = load i64, i64* %ptr_t
  %r49 = getelementptr [5 x i8], [5 x i8]* @.str.234, i64 0, i64 0
  %r50 = ptrtoint i8* %r49 to i64
  %r51 = call i64 @_get(i64 %r48, i64 %r50)
  store i64 %r51, i64* %ptr_op
  %r52 = call i64 @advance()
  %r53 = call i64 @parse_bitwise()
  store i64 %r53, i64* %ptr_right
  %r54 = call i64 @_map_new()
  %r55 = getelementptr [5 x i8], [5 x i8]* @.str.235, i64 0, i64 0
  %r56 = ptrtoint i8* %r55 to i64
  %r57 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r54, i64 %r56, i64 %r57)
  %r58 = getelementptr [3 x i8], [3 x i8]* @.str.236, i64 0, i64 0
  %r59 = ptrtoint i8* %r58 to i64
  %r60 = load i64, i64* %ptr_op
  call i64 @_map_set(i64 %r54, i64 %r59, i64 %r60)
  %r61 = getelementptr [5 x i8], [5 x i8]* @.str.237, i64 0, i64 0
  %r62 = ptrtoint i8* %r61 to i64
  %r63 = load i64, i64* %ptr_left
  call i64 @_map_set(i64 %r54, i64 %r62, i64 %r63)
  %r64 = getelementptr [6 x i8], [6 x i8]* @.str.238, i64 0, i64 0
  %r65 = ptrtoint i8* %r64 to i64
  %r66 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r54, i64 %r65, i64 %r66)
  store i64 %r54, i64* %ptr_left
  %r67 = call i64 @peek()
  store i64 %r67, i64* %ptr_t
  br label %L825
L824:
  store i64 0, i64* %ptr_running
  br label %L825
L825:
  br label %L799
L801:
  %r68 = load i64, i64* %ptr_left
  ret i64 %r68
  ret i64 0
}
define i64 @parse_expr() {
  %ptr_left = alloca i64
  %ptr_t = alloca i64
  %ptr_running = alloca i64
  %ptr_is_op = alloca i64
  %ptr_op = alloca i64
  %ptr_right = alloca i64
  %r1 = call i64 @parse_cmp()
  store i64 %r1, i64* %ptr_left
  %r2 = call i64 @peek()
  store i64 %r2, i64* %ptr_t
  store i64 1, i64* %ptr_running
  br label %L826
L826:
  %r3 = load i64, i64* %ptr_running
  %r4 = icmp ne i64 %r3, 0
  br i1 %r4, label %L827, label %L828
L827:
  store i64 0, i64* %ptr_is_op
  %r5 = load i64, i64* %ptr_t
  %r6 = getelementptr [5 x i8], [5 x i8]* @.str.240, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  %r8 = call i64 @_get(i64 %r5, i64 %r7)
  %r9 = load i64, i64* @TOK_AND
  %r10 = call i64 @_eq(i64 %r8, i64 %r9)
  store i64 1, i64* @.sc.239
  %r12 = icmp eq i64 %r10, 0
  br i1 %r12, label %L829, label %L830
L829:
  %r13 = load i64, i64* %ptr_t
  %r14 = getelementptr [5 x i8], [5 x i8]* @.str.241, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  %r16 = call i64 @_get(i64 %r13, i64 %r15)
  %r17 = load i64, i64* @TOK_OR
  %r18 = call i64 @_eq(i64 %r16, i64 %r17)
  %r19 = icmp ne i64 %r18, 0
  %r20 = zext i1 %r19 to i64
  store i64 %r20, i64* @.sc.239
  br label %L830
L830:
  %r11 = load i64, i64* @.sc.239
  %r21 = icmp ne i64 %r11, 0
  br i1 %r21, label %L831, label %L833
L831:
  store i64 1, i64* %ptr_is_op
  br label %L833
L833:
  %r22 = load i64, i64* %ptr_is_op
  %r23 = icmp ne i64 %r22, 0
  br i1 %r23, label %L834, label %L835
L834:
  %r24 = getelementptr [3 x i8], [3 x i8]* @.str.242, i64 0, i64 0
  %r25 = ptrtoint i8* %r24 to i64
  store i64 %r25, i64* %ptr_op
  %r26 = load i64, i64* %ptr_t
  %r27 = getelementptr [5 x i8], [5 x i8]* @.str.243, i64 0, i64 0
  %r28 = ptrtoint i8* %r27 to i64
  %r29 = call i64 @_get(i64 %r26, i64 %r28)
  %r30 = load i64, i64* @TOK_OR
  %r31 = call i64 @_eq(i64 %r29, i64 %r30)
  %r32 = icmp ne i64 %r31, 0
  br i1 %r32, label %L837, label %L839
L837:
  %r33 = getelementptr [4 x i8], [4 x i8]* @.str.244, i64 0, i64 0
  %r34 = ptrtoint i8* %r33 to i64
  store i64 %r34, i64* %ptr_op
  br label %L839
L839:
  %r35 = call i64 @advance()
  %r36 = call i64 @parse_cmp()
  store i64 %r36, i64* %ptr_right
  %r37 = call i64 @_map_new()
  %r38 = getelementptr [5 x i8], [5 x i8]* @.str.245, i64 0, i64 0
  %r39 = ptrtoint i8* %r38 to i64
  %r40 = load i64, i64* @EXPR_BINARY
  call i64 @_map_set(i64 %r37, i64 %r39, i64 %r40)
  %r41 = getelementptr [3 x i8], [3 x i8]* @.str.246, i64 0, i64 0
  %r42 = ptrtoint i8* %r41 to i64
  %r43 = load i64, i64* %ptr_op
  call i64 @_map_set(i64 %r37, i64 %r42, i64 %r43)
  %r44 = getelementptr [5 x i8], [5 x i8]* @.str.247, i64 0, i64 0
  %r45 = ptrtoint i8* %r44 to i64
  %r46 = load i64, i64* %ptr_left
  call i64 @_map_set(i64 %r37, i64 %r45, i64 %r46)
  %r47 = getelementptr [6 x i8], [6 x i8]* @.str.248, i64 0, i64 0
  %r48 = ptrtoint i8* %r47 to i64
  %r49 = load i64, i64* %ptr_right
  call i64 @_map_set(i64 %r37, i64 %r48, i64 %r49)
  store i64 %r37, i64* %ptr_left
  %r50 = call i64 @peek()
  store i64 %r50, i64* %ptr_t
  br label %L836
L835:
  store i64 0, i64* %ptr_running
  br label %L836
L836:
  br label %L826
L828:
  %r51 = load i64, i64* %ptr_left
  ret i64 %r51
  ret i64 0
}
define i64 @parse_stmt() {
  %ptr_t = alloca i64
  %ptr_stmt_type = alloca i64
  %ptr_name = alloca i64
  %ptr_val = alloca i64
  %ptr_cond = alloca i64
  %ptr_body = alloca i64
  %ptr_else_body = alloca i64
  %ptr_params = alloca i64
  %ptr_p = alloca i64
  %ptr_path = alloca i64
  %ptr_next_idx = alloca i64
  %ptr_next = alloca i64
  %ptr_lhs = alloca i64
  %ptr_arr_nm = alloca i64
  %ptr_expr = alloca i64
  %r1 = call i64 @peek()
  store i64 %r1, i64* %ptr_t
  %r2 = sub i64 0, 1
  store i64 %r2, i64* %ptr_stmt_type
  %r3 = load i64, i64* %ptr_t
  %r4 = getelementptr [5 x i8], [5 x i8]* @.str.249, i64 0, i64 0
  %r5 = ptrtoint i8* %r4 to i64
  %r6 = call i64 @_get(i64 %r3, i64 %r5)
  %r7 = load i64, i64* @TOK_LET
  %r8 = call i64 @_eq(i64 %r6, i64 %r7)
  %r9 = icmp ne i64 %r8, 0
  br i1 %r9, label %L840, label %L841
L840:
  %r10 = load i64, i64* @STMT_LET
  store i64 %r10, i64* %ptr_stmt_type
  %r11 = load i64, i64* @TOK_LET
  %r12 = call i64 @consume(i64 %r11)
  br label %L842
L841:
  %r13 = load i64, i64* %ptr_t
  %r14 = getelementptr [5 x i8], [5 x i8]* @.str.250, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  %r16 = call i64 @_get(i64 %r13, i64 %r15)
  %r17 = load i64, i64* @TOK_SHARED
  %r18 = call i64 @_eq(i64 %r16, i64 %r17)
  %r19 = icmp ne i64 %r18, 0
  br i1 %r19, label %L843, label %L844
L843:
  %r20 = load i64, i64* @STMT_SHARED
  store i64 %r20, i64* %ptr_stmt_type
  %r21 = load i64, i64* @TOK_SHARED
  %r22 = call i64 @consume(i64 %r21)
  br label %L845
L844:
  %r23 = load i64, i64* %ptr_t
  %r24 = getelementptr [5 x i8], [5 x i8]* @.str.251, i64 0, i64 0
  %r25 = ptrtoint i8* %r24 to i64
  %r26 = call i64 @_get(i64 %r23, i64 %r25)
  %r27 = load i64, i64* @TOK_CONST
  %r28 = call i64 @_eq(i64 %r26, i64 %r27)
  %r29 = icmp ne i64 %r28, 0
  br i1 %r29, label %L846, label %L848
L846:
  %r30 = load i64, i64* @STMT_CONST
  store i64 %r30, i64* %ptr_stmt_type
  %r31 = load i64, i64* @TOK_CONST
  %r32 = call i64 @consume(i64 %r31)
  br label %L848
L848:
  br label %L845
L845:
  br label %L842
L842:
  %r33 = load i64, i64* %ptr_stmt_type
  %r34 = sub i64 0, 1
  %r36 = call i64 @_eq(i64 %r33, i64 %r34)
  %r35 = xor i64 %r36, 1
  %r37 = icmp ne i64 %r35, 0
  br i1 %r37, label %L849, label %L851
L849:
  %r38 = call i64 @advance()
  store i64 %r38, i64* %ptr_name
  %r39 = load i64, i64* @TOK_COLON
  %r40 = call i64 @expect(i64 %r39)
  %r41 = call i64 @advance()
  %r42 = load i64, i64* @TOK_ARROW
  %r43 = call i64 @expect(i64 %r42)
  %r44 = call i64 @parse_expr()
  store i64 %r44, i64* %ptr_val
  %r45 = load i64, i64* @TOK_CARET
  %r46 = call i64 @expect(i64 %r45)
  %r47 = call i64 @_map_new()
  %r48 = getelementptr [5 x i8], [5 x i8]* @.str.252, i64 0, i64 0
  %r49 = ptrtoint i8* %r48 to i64
  %r50 = load i64, i64* %ptr_stmt_type
  call i64 @_map_set(i64 %r47, i64 %r49, i64 %r50)
  %r51 = getelementptr [5 x i8], [5 x i8]* @.str.253, i64 0, i64 0
  %r52 = ptrtoint i8* %r51 to i64
  %r53 = load i64, i64* %ptr_name
  %r54 = getelementptr [5 x i8], [5 x i8]* @.str.254, i64 0, i64 0
  %r55 = ptrtoint i8* %r54 to i64
  %r56 = call i64 @_get(i64 %r53, i64 %r55)
  call i64 @_map_set(i64 %r47, i64 %r52, i64 %r56)
  %r57 = getelementptr [4 x i8], [4 x i8]* @.str.255, i64 0, i64 0
  %r58 = ptrtoint i8* %r57 to i64
  %r59 = load i64, i64* %ptr_val
  call i64 @_map_set(i64 %r47, i64 %r58, i64 %r59)
  ret i64 %r47
  br label %L851
L851:
  %r60 = load i64, i64* @TOK_PRINT
  %r61 = call i64 @consume(i64 %r60)
  %r62 = icmp ne i64 %r61, 0
  br i1 %r62, label %L852, label %L854
L852:
  %r63 = load i64, i64* @TOK_LPAREN
  %r64 = call i64 @expect(i64 %r63)
  %r65 = call i64 @parse_expr()
  store i64 %r65, i64* %ptr_val
  %r66 = load i64, i64* @TOK_RPAREN
  %r67 = call i64 @expect(i64 %r66)
  %r68 = load i64, i64* @TOK_CARET
  %r69 = call i64 @expect(i64 %r68)
  %r70 = call i64 @_map_new()
  %r71 = getelementptr [5 x i8], [5 x i8]* @.str.256, i64 0, i64 0
  %r72 = ptrtoint i8* %r71 to i64
  %r73 = load i64, i64* @STMT_PRINT
  call i64 @_map_set(i64 %r70, i64 %r72, i64 %r73)
  %r74 = getelementptr [4 x i8], [4 x i8]* @.str.257, i64 0, i64 0
  %r75 = ptrtoint i8* %r74 to i64
  %r76 = load i64, i64* %ptr_val
  call i64 @_map_set(i64 %r70, i64 %r75, i64 %r76)
  ret i64 %r70
  br label %L854
L854:
  %r77 = load i64, i64* @TOK_IF
  %r78 = call i64 @consume(i64 %r77)
  %r79 = icmp ne i64 %r78, 0
  br i1 %r79, label %L855, label %L857
L855:
  %r80 = load i64, i64* @TOK_LPAREN
  %r81 = call i64 @expect(i64 %r80)
  %r82 = call i64 @parse_expr()
  store i64 %r82, i64* %ptr_cond
  %r83 = load i64, i64* @TOK_RPAREN
  %r84 = call i64 @expect(i64 %r83)
  %r85 = load i64, i64* @TOK_LBRACE
  %r86 = call i64 @expect(i64 %r85)
  %r87 = call i64 @_list_new()
  store i64 %r87, i64* %ptr_body
  br label %L858
L858:
  %r88 = call i64 @peek()
  %r89 = getelementptr [5 x i8], [5 x i8]* @.str.258, i64 0, i64 0
  %r90 = ptrtoint i8* %r89 to i64
  %r91 = call i64 @_get(i64 %r88, i64 %r90)
  %r92 = load i64, i64* @TOK_RBRACE
  %r94 = call i64 @_eq(i64 %r91, i64 %r92)
  %r93 = xor i64 %r94, 1
  %r95 = icmp ne i64 %r93, 0
  br i1 %r95, label %L859, label %L860
L859:
  %r96 = call i64 @peek()
  %r97 = getelementptr [5 x i8], [5 x i8]* @.str.259, i64 0, i64 0
  %r98 = ptrtoint i8* %r97 to i64
  %r99 = call i64 @_get(i64 %r96, i64 %r98)
  %r100 = load i64, i64* @TOK_CARET
  %r101 = call i64 @_eq(i64 %r99, i64 %r100)
  %r102 = icmp ne i64 %r101, 0
  br i1 %r102, label %L861, label %L863
L861:
  %r103 = call i64 @advance()
  br label %L858
L863:
  %r104 = call i64 @parse_stmt()
  %r105 = load i64, i64* %ptr_body
  call i64 @_append_poly(i64 %r105, i64 %r104)
  br label %L858
L860:
  %r106 = load i64, i64* @TOK_RBRACE
  %r107 = call i64 @expect(i64 %r106)
  %r108 = call i64 @_list_new()
  store i64 %r108, i64* %ptr_else_body
  %r109 = load i64, i64* @TOK_ELSE
  %r110 = call i64 @consume(i64 %r109)
  %r111 = icmp ne i64 %r110, 0
  br i1 %r111, label %L864, label %L866
L864:
  %r112 = call i64 @peek()
  %r113 = getelementptr [5 x i8], [5 x i8]* @.str.260, i64 0, i64 0
  %r114 = ptrtoint i8* %r113 to i64
  %r115 = call i64 @_get(i64 %r112, i64 %r114)
  %r116 = load i64, i64* @TOK_IF
  %r117 = call i64 @_eq(i64 %r115, i64 %r116)
  %r118 = icmp ne i64 %r117, 0
  br i1 %r118, label %L867, label %L868
L867:
  %r119 = call i64 @parse_stmt()
  %r120 = load i64, i64* %ptr_else_body
  call i64 @_append_poly(i64 %r120, i64 %r119)
  br label %L869
L868:
  %r121 = load i64, i64* @TOK_LBRACE
  %r122 = call i64 @expect(i64 %r121)
  br label %L870
L870:
  %r123 = call i64 @peek()
  %r124 = getelementptr [5 x i8], [5 x i8]* @.str.261, i64 0, i64 0
  %r125 = ptrtoint i8* %r124 to i64
  %r126 = call i64 @_get(i64 %r123, i64 %r125)
  %r127 = load i64, i64* @TOK_RBRACE
  %r129 = call i64 @_eq(i64 %r126, i64 %r127)
  %r128 = xor i64 %r129, 1
  %r130 = icmp ne i64 %r128, 0
  br i1 %r130, label %L871, label %L872
L871:
  %r131 = call i64 @peek()
  %r132 = getelementptr [5 x i8], [5 x i8]* @.str.262, i64 0, i64 0
  %r133 = ptrtoint i8* %r132 to i64
  %r134 = call i64 @_get(i64 %r131, i64 %r133)
  %r135 = load i64, i64* @TOK_CARET
  %r136 = call i64 @_eq(i64 %r134, i64 %r135)
  %r137 = icmp ne i64 %r136, 0
  br i1 %r137, label %L873, label %L875
L873:
  %r138 = call i64 @advance()
  br label %L870
L875:
  %r139 = call i64 @parse_stmt()
  %r140 = load i64, i64* %ptr_else_body
  call i64 @_append_poly(i64 %r140, i64 %r139)
  br label %L870
L872:
  %r141 = load i64, i64* @TOK_RBRACE
  %r142 = call i64 @expect(i64 %r141)
  br label %L869
L869:
  br label %L866
L866:
  %r143 = call i64 @_map_new()
  %r144 = getelementptr [5 x i8], [5 x i8]* @.str.263, i64 0, i64 0
  %r145 = ptrtoint i8* %r144 to i64
  %r146 = load i64, i64* @STMT_IF
  call i64 @_map_set(i64 %r143, i64 %r145, i64 %r146)
  %r147 = getelementptr [5 x i8], [5 x i8]* @.str.264, i64 0, i64 0
  %r148 = ptrtoint i8* %r147 to i64
  %r149 = load i64, i64* %ptr_cond
  call i64 @_map_set(i64 %r143, i64 %r148, i64 %r149)
  %r150 = getelementptr [5 x i8], [5 x i8]* @.str.265, i64 0, i64 0
  %r151 = ptrtoint i8* %r150 to i64
  %r152 = load i64, i64* %ptr_body
  call i64 @_map_set(i64 %r143, i64 %r151, i64 %r152)
  %r153 = getelementptr [5 x i8], [5 x i8]* @.str.266, i64 0, i64 0
  %r154 = ptrtoint i8* %r153 to i64
  %r155 = load i64, i64* %ptr_else_body
  call i64 @_map_set(i64 %r143, i64 %r154, i64 %r155)
  ret i64 %r143
  br label %L857
L857:
  %r156 = load i64, i64* @TOK_WHILE
  %r157 = call i64 @consume(i64 %r156)
  %r158 = icmp ne i64 %r157, 0
  br i1 %r158, label %L876, label %L878
L876:
  %r159 = load i64, i64* @TOK_LPAREN
  %r160 = call i64 @expect(i64 %r159)
  %r161 = call i64 @parse_expr()
  store i64 %r161, i64* %ptr_cond
  %r162 = load i64, i64* @TOK_RPAREN
  %r163 = call i64 @expect(i64 %r162)
  %r164 = load i64, i64* @TOK_LBRACE
  %r165 = call i64 @expect(i64 %r164)
  %r166 = call i64 @_list_new()
  store i64 %r166, i64* %ptr_body
  br label %L879
L879:
  %r167 = call i64 @peek()
  %r168 = getelementptr [5 x i8], [5 x i8]* @.str.267, i64 0, i64 0
  %r169 = ptrtoint i8* %r168 to i64
  %r170 = call i64 @_get(i64 %r167, i64 %r169)
  %r171 = load i64, i64* @TOK_RBRACE
  %r173 = call i64 @_eq(i64 %r170, i64 %r171)
  %r172 = xor i64 %r173, 1
  %r174 = icmp ne i64 %r172, 0
  br i1 %r174, label %L880, label %L881
L880:
  %r175 = call i64 @parse_stmt()
  %r176 = load i64, i64* %ptr_body
  call i64 @_append_poly(i64 %r176, i64 %r175)
  br label %L879
L881:
  %r177 = load i64, i64* @TOK_RBRACE
  %r178 = call i64 @expect(i64 %r177)
  %r179 = call i64 @_map_new()
  %r180 = getelementptr [5 x i8], [5 x i8]* @.str.268, i64 0, i64 0
  %r181 = ptrtoint i8* %r180 to i64
  %r182 = load i64, i64* @STMT_WHILE
  call i64 @_map_set(i64 %r179, i64 %r181, i64 %r182)
  %r183 = getelementptr [5 x i8], [5 x i8]* @.str.269, i64 0, i64 0
  %r184 = ptrtoint i8* %r183 to i64
  %r185 = load i64, i64* %ptr_cond
  call i64 @_map_set(i64 %r179, i64 %r184, i64 %r185)
  %r186 = getelementptr [5 x i8], [5 x i8]* @.str.270, i64 0, i64 0
  %r187 = ptrtoint i8* %r186 to i64
  %r188 = load i64, i64* %ptr_body
  call i64 @_map_set(i64 %r179, i64 %r187, i64 %r188)
  ret i64 %r179
  br label %L878
L878:
  %r189 = load i64, i64* @TOK_OPUS
  %r190 = call i64 @consume(i64 %r189)
  %r191 = icmp ne i64 %r190, 0
  br i1 %r191, label %L882, label %L884
L882:
  %r192 = call i64 @advance()
  store i64 %r192, i64* %ptr_name
  %r193 = load i64, i64* @TOK_LPAREN
  %r194 = call i64 @expect(i64 %r193)
  %r195 = call i64 @_list_new()
  store i64 %r195, i64* %ptr_params
  %r196 = call i64 @peek()
  %r197 = getelementptr [5 x i8], [5 x i8]* @.str.271, i64 0, i64 0
  %r198 = ptrtoint i8* %r197 to i64
  %r199 = call i64 @_get(i64 %r196, i64 %r198)
  %r200 = load i64, i64* @TOK_RPAREN
  %r202 = call i64 @_eq(i64 %r199, i64 %r200)
  %r201 = xor i64 %r202, 1
  %r203 = icmp ne i64 %r201, 0
  br i1 %r203, label %L885, label %L887
L885:
  %r204 = call i64 @advance()
  store i64 %r204, i64* %ptr_p
  %r205 = load i64, i64* %ptr_p
  %r206 = getelementptr [5 x i8], [5 x i8]* @.str.272, i64 0, i64 0
  %r207 = ptrtoint i8* %r206 to i64
  %r208 = call i64 @_get(i64 %r205, i64 %r207)
  %r209 = load i64, i64* %ptr_params
  call i64 @_append_poly(i64 %r209, i64 %r208)
  br label %L888
L888:
  %r210 = load i64, i64* @TOK_COMMA
  %r211 = call i64 @consume(i64 %r210)
  %r212 = icmp ne i64 %r211, 0
  br i1 %r212, label %L889, label %L890
L889:
  %r213 = call i64 @advance()
  store i64 %r213, i64* %ptr_p
  %r214 = load i64, i64* %ptr_p
  %r215 = getelementptr [5 x i8], [5 x i8]* @.str.273, i64 0, i64 0
  %r216 = ptrtoint i8* %r215 to i64
  %r217 = call i64 @_get(i64 %r214, i64 %r216)
  %r218 = load i64, i64* %ptr_params
  call i64 @_append_poly(i64 %r218, i64 %r217)
  br label %L888
L890:
  br label %L887
L887:
  %r219 = load i64, i64* @TOK_RPAREN
  %r220 = call i64 @expect(i64 %r219)
  %r221 = load i64, i64* @TOK_LBRACE
  %r222 = call i64 @expect(i64 %r221)
  %r223 = call i64 @_list_new()
  store i64 %r223, i64* %ptr_body
  br label %L891
L891:
  %r224 = call i64 @peek()
  %r225 = getelementptr [5 x i8], [5 x i8]* @.str.274, i64 0, i64 0
  %r226 = ptrtoint i8* %r225 to i64
  %r227 = call i64 @_get(i64 %r224, i64 %r226)
  %r228 = load i64, i64* @TOK_RBRACE
  %r230 = call i64 @_eq(i64 %r227, i64 %r228)
  %r229 = xor i64 %r230, 1
  %r231 = icmp ne i64 %r229, 0
  br i1 %r231, label %L892, label %L893
L892:
  %r232 = call i64 @parse_stmt()
  %r233 = load i64, i64* %ptr_body
  call i64 @_append_poly(i64 %r233, i64 %r232)
  br label %L891
L893:
  %r234 = load i64, i64* @TOK_RBRACE
  %r235 = call i64 @expect(i64 %r234)
  %r236 = call i64 @_map_new()
  %r237 = getelementptr [5 x i8], [5 x i8]* @.str.275, i64 0, i64 0
  %r238 = ptrtoint i8* %r237 to i64
  %r239 = load i64, i64* @STMT_FUNC
  call i64 @_map_set(i64 %r236, i64 %r238, i64 %r239)
  %r240 = getelementptr [5 x i8], [5 x i8]* @.str.276, i64 0, i64 0
  %r241 = ptrtoint i8* %r240 to i64
  %r242 = load i64, i64* %ptr_name
  %r243 = getelementptr [5 x i8], [5 x i8]* @.str.277, i64 0, i64 0
  %r244 = ptrtoint i8* %r243 to i64
  %r245 = call i64 @_get(i64 %r242, i64 %r244)
  call i64 @_map_set(i64 %r236, i64 %r241, i64 %r245)
  %r246 = getelementptr [7 x i8], [7 x i8]* @.str.278, i64 0, i64 0
  %r247 = ptrtoint i8* %r246 to i64
  %r248 = load i64, i64* %ptr_params
  call i64 @_map_set(i64 %r236, i64 %r247, i64 %r248)
  %r249 = getelementptr [5 x i8], [5 x i8]* @.str.279, i64 0, i64 0
  %r250 = ptrtoint i8* %r249 to i64
  %r251 = load i64, i64* %ptr_body
  call i64 @_map_set(i64 %r236, i64 %r250, i64 %r251)
  ret i64 %r236
  br label %L884
L884:
  %r252 = load i64, i64* @TOK_REDDO
  %r253 = call i64 @consume(i64 %r252)
  %r254 = icmp ne i64 %r253, 0
  br i1 %r254, label %L894, label %L896
L894:
  %r255 = call i64 @parse_expr()
  store i64 %r255, i64* %ptr_val
  %r256 = load i64, i64* @TOK_CARET
  %r257 = call i64 @expect(i64 %r256)
  %r258 = call i64 @_map_new()
  %r259 = getelementptr [5 x i8], [5 x i8]* @.str.280, i64 0, i64 0
  %r260 = ptrtoint i8* %r259 to i64
  %r261 = load i64, i64* @STMT_RETURN
  call i64 @_map_set(i64 %r258, i64 %r260, i64 %r261)
  %r262 = getelementptr [4 x i8], [4 x i8]* @.str.281, i64 0, i64 0
  %r263 = ptrtoint i8* %r262 to i64
  %r264 = load i64, i64* %ptr_val
  call i64 @_map_set(i64 %r258, i64 %r263, i64 %r264)
  ret i64 %r258
  br label %L896
L896:
  %r265 = load i64, i64* @TOK_BREAK
  %r266 = call i64 @consume(i64 %r265)
  %r267 = icmp ne i64 %r266, 0
  br i1 %r267, label %L897, label %L899
L897:
  %r268 = load i64, i64* @TOK_CARET
  %r269 = call i64 @expect(i64 %r268)
  %r270 = call i64 @_map_new()
  %r271 = getelementptr [5 x i8], [5 x i8]* @.str.282, i64 0, i64 0
  %r272 = ptrtoint i8* %r271 to i64
  %r273 = load i64, i64* @STMT_BREAK
  call i64 @_map_set(i64 %r270, i64 %r272, i64 %r273)
  ret i64 %r270
  br label %L899
L899:
  %r274 = load i64, i64* @TOK_CONTINUE
  %r275 = call i64 @consume(i64 %r274)
  %r276 = icmp ne i64 %r275, 0
  br i1 %r276, label %L900, label %L902
L900:
  %r277 = load i64, i64* @TOK_CARET
  %r278 = call i64 @expect(i64 %r277)
  %r279 = call i64 @_map_new()
  %r280 = getelementptr [5 x i8], [5 x i8]* @.str.283, i64 0, i64 0
  %r281 = ptrtoint i8* %r280 to i64
  %r282 = load i64, i64* @STMT_CONTINUE
  call i64 @_map_set(i64 %r279, i64 %r281, i64 %r282)
  ret i64 %r279
  br label %L902
L902:
  %r283 = load i64, i64* @TOK_IMPORT
  %r284 = call i64 @consume(i64 %r283)
  %r285 = icmp ne i64 %r284, 0
  br i1 %r285, label %L903, label %L905
L903:
  %r286 = load i64, i64* @TOK_LPAREN
  %r287 = call i64 @expect(i64 %r286)
  %r288 = call i64 @parse_expr()
  store i64 %r288, i64* %ptr_path
  %r289 = load i64, i64* @TOK_RPAREN
  %r290 = call i64 @expect(i64 %r289)
  %r291 = load i64, i64* @TOK_CARET
  %r292 = call i64 @expect(i64 %r291)
  %r293 = call i64 @_map_new()
  %r294 = getelementptr [5 x i8], [5 x i8]* @.str.284, i64 0, i64 0
  %r295 = ptrtoint i8* %r294 to i64
  %r296 = load i64, i64* @STMT_IMPORT
  call i64 @_map_set(i64 %r293, i64 %r295, i64 %r296)
  %r297 = getelementptr [4 x i8], [4 x i8]* @.str.285, i64 0, i64 0
  %r298 = ptrtoint i8* %r297 to i64
  %r299 = load i64, i64* %ptr_path
  call i64 @_map_set(i64 %r293, i64 %r298, i64 %r299)
  ret i64 %r293
  br label %L905
L905:
  %r300 = load i64, i64* %ptr_t
  %r301 = getelementptr [5 x i8], [5 x i8]* @.str.286, i64 0, i64 0
  %r302 = ptrtoint i8* %r301 to i64
  %r303 = call i64 @_get(i64 %r300, i64 %r302)
  %r304 = load i64, i64* @TOK_IDENT
  %r305 = call i64 @_eq(i64 %r303, i64 %r304)
  %r306 = icmp ne i64 %r305, 0
  br i1 %r306, label %L906, label %L908
L906:
  %r307 = load i64, i64* @p_pos
  %r308 = call i64 @_add(i64 %r307, i64 1)
  store i64 %r308, i64* %ptr_next_idx
  %r309 = load i64, i64* %ptr_next_idx
  %r310 = load i64, i64* @global_tokens
  %r311 = call i64 @mensura(i64 %r310)
  %r313 = icmp sge i64 %r309, %r311
  %r312 = zext i1 %r313 to i64
  %r314 = icmp ne i64 %r312, 0
  br i1 %r314, label %L909, label %L911
L909:
  %r315 = getelementptr [15 x i8], [15 x i8]* @.str.287, i64 0, i64 0
  %r316 = ptrtoint i8* %r315 to i64
  %r317 = call i64 @error_report(i64 %r316)
  %r318 = call i64 @_map_new()
  %r319 = getelementptr [5 x i8], [5 x i8]* @.str.288, i64 0, i64 0
  %r320 = ptrtoint i8* %r319 to i64
  %r321 = sub i64 0, 1
  call i64 @_map_set(i64 %r318, i64 %r320, i64 %r321)
  ret i64 %r318
  br label %L911
L911:
  %r322 = load i64, i64* @global_tokens
  %r323 = load i64, i64* %ptr_next_idx
  %r324 = call i64 @_get(i64 %r322, i64 %r323)
  store i64 %r324, i64* %ptr_next
  %r325 = load i64, i64* %ptr_next
  %r326 = getelementptr [5 x i8], [5 x i8]* @.str.289, i64 0, i64 0
  %r327 = ptrtoint i8* %r326 to i64
  %r328 = call i64 @_get(i64 %r325, i64 %r327)
  %r329 = load i64, i64* @TOK_ARROW
  %r330 = call i64 @_eq(i64 %r328, i64 %r329)
  %r331 = icmp ne i64 %r330, 0
  br i1 %r331, label %L912, label %L914
L912:
  %r332 = call i64 @advance()
  store i64 %r332, i64* %ptr_name
  %r333 = call i64 @advance()
  %r334 = call i64 @parse_expr()
  store i64 %r334, i64* %ptr_val
  %r335 = load i64, i64* @TOK_CARET
  %r336 = call i64 @expect(i64 %r335)
  %r337 = call i64 @_map_new()
  %r338 = getelementptr [5 x i8], [5 x i8]* @.str.290, i64 0, i64 0
  %r339 = ptrtoint i8* %r338 to i64
  %r340 = load i64, i64* @STMT_ASSIGN
  call i64 @_map_set(i64 %r337, i64 %r339, i64 %r340)
  %r341 = getelementptr [5 x i8], [5 x i8]* @.str.291, i64 0, i64 0
  %r342 = ptrtoint i8* %r341 to i64
  %r343 = load i64, i64* %ptr_name
  %r344 = getelementptr [5 x i8], [5 x i8]* @.str.292, i64 0, i64 0
  %r345 = ptrtoint i8* %r344 to i64
  %r346 = call i64 @_get(i64 %r343, i64 %r345)
  call i64 @_map_set(i64 %r337, i64 %r342, i64 %r346)
  %r347 = getelementptr [4 x i8], [4 x i8]* @.str.293, i64 0, i64 0
  %r348 = ptrtoint i8* %r347 to i64
  %r349 = load i64, i64* %ptr_val
  call i64 @_map_set(i64 %r337, i64 %r348, i64 %r349)
  ret i64 %r337
  br label %L914
L914:
  %r350 = load i64, i64* %ptr_next
  %r351 = getelementptr [5 x i8], [5 x i8]* @.str.294, i64 0, i64 0
  %r352 = ptrtoint i8* %r351 to i64
  %r353 = call i64 @_get(i64 %r350, i64 %r352)
  %r354 = load i64, i64* @TOK_APPEND
  %r355 = call i64 @_eq(i64 %r353, i64 %r354)
  %r356 = icmp ne i64 %r355, 0
  br i1 %r356, label %L915, label %L917
L915:
  %r357 = call i64 @advance()
  store i64 %r357, i64* %ptr_name
  %r358 = call i64 @advance()
  %r359 = call i64 @parse_expr()
  store i64 %r359, i64* %ptr_val
  %r360 = load i64, i64* @TOK_CARET
  %r361 = call i64 @expect(i64 %r360)
  %r362 = call i64 @_map_new()
  %r363 = getelementptr [5 x i8], [5 x i8]* @.str.295, i64 0, i64 0
  %r364 = ptrtoint i8* %r363 to i64
  %r365 = load i64, i64* @STMT_APPEND
  call i64 @_map_set(i64 %r362, i64 %r364, i64 %r365)
  %r366 = getelementptr [5 x i8], [5 x i8]* @.str.296, i64 0, i64 0
  %r367 = ptrtoint i8* %r366 to i64
  %r368 = load i64, i64* %ptr_name
  %r369 = getelementptr [5 x i8], [5 x i8]* @.str.297, i64 0, i64 0
  %r370 = ptrtoint i8* %r369 to i64
  %r371 = call i64 @_get(i64 %r368, i64 %r370)
  call i64 @_map_set(i64 %r362, i64 %r367, i64 %r371)
  %r372 = getelementptr [4 x i8], [4 x i8]* @.str.298, i64 0, i64 0
  %r373 = ptrtoint i8* %r372 to i64
  %r374 = load i64, i64* %ptr_val
  call i64 @_map_set(i64 %r362, i64 %r373, i64 %r374)
  ret i64 %r362
  br label %L917
L917:
  %r375 = load i64, i64* %ptr_next
  %r376 = getelementptr [5 x i8], [5 x i8]* @.str.299, i64 0, i64 0
  %r377 = ptrtoint i8* %r376 to i64
  %r378 = call i64 @_get(i64 %r375, i64 %r377)
  %r379 = load i64, i64* @TOK_LBRACKET
  %r380 = call i64 @_eq(i64 %r378, i64 %r379)
  %r381 = icmp ne i64 %r380, 0
  br i1 %r381, label %L918, label %L920
L918:
  %r382 = call i64 @parse_expr()
  store i64 %r382, i64* %ptr_lhs
  %r383 = load i64, i64* @TOK_ARROW
  %r384 = call i64 @consume(i64 %r383)
  %r385 = icmp ne i64 %r384, 0
  br i1 %r385, label %L921, label %L923
L921:
  %r386 = call i64 @parse_expr()
  store i64 %r386, i64* %ptr_val
  %r387 = load i64, i64* @TOK_CARET
  %r388 = call i64 @expect(i64 %r387)
  %r389 = load i64, i64* %ptr_lhs
  %r390 = getelementptr [5 x i8], [5 x i8]* @.str.300, i64 0, i64 0
  %r391 = ptrtoint i8* %r390 to i64
  %r392 = call i64 @_get(i64 %r389, i64 %r391)
  %r393 = load i64, i64* @EXPR_INDEX
  %r394 = call i64 @_eq(i64 %r392, i64 %r393)
  %r395 = icmp ne i64 %r394, 0
  br i1 %r395, label %L924, label %L926
L924:
  %r396 = load i64, i64* %ptr_lhs
  %r397 = getelementptr [4 x i8], [4 x i8]* @.str.301, i64 0, i64 0
  %r398 = ptrtoint i8* %r397 to i64
  %r399 = call i64 @_get(i64 %r396, i64 %r398)
  store i64 %r399, i64* %ptr_arr_nm
  %r400 = call i64 @_map_new()
  %r401 = getelementptr [5 x i8], [5 x i8]* @.str.302, i64 0, i64 0
  %r402 = ptrtoint i8* %r401 to i64
  %r403 = load i64, i64* @STMT_SET_INDEX
  call i64 @_map_set(i64 %r400, i64 %r402, i64 %r403)
  %r404 = getelementptr [5 x i8], [5 x i8]* @.str.303, i64 0, i64 0
  %r405 = ptrtoint i8* %r404 to i64
  %r406 = load i64, i64* %ptr_arr_nm
  %r407 = getelementptr [5 x i8], [5 x i8]* @.str.304, i64 0, i64 0
  %r408 = ptrtoint i8* %r407 to i64
  %r409 = call i64 @_get(i64 %r406, i64 %r408)
  call i64 @_map_set(i64 %r400, i64 %r405, i64 %r409)
  %r410 = getelementptr [4 x i8], [4 x i8]* @.str.305, i64 0, i64 0
  %r411 = ptrtoint i8* %r410 to i64
  %r412 = load i64, i64* %ptr_lhs
  %r413 = getelementptr [4 x i8], [4 x i8]* @.str.306, i64 0, i64 0
  %r414 = ptrtoint i8* %r413 to i64
  %r415 = call i64 @_get(i64 %r412, i64 %r414)
  call i64 @_map_set(i64 %r400, i64 %r411, i64 %r415)
  %r416 = getelementptr [4 x i8], [4 x i8]* @.str.307, i64 0, i64 0
  %r417 = ptrtoint i8* %r416 to i64
  %r418 = load i64, i64* %ptr_val
  call i64 @_map_set(i64 %r400, i64 %r417, i64 %r418)
  ret i64 %r400
  br label %L926
L926:
  br label %L923
L923:
  br label %L920
L920:
  %r419 = load i64, i64* %ptr_next
  %r420 = getelementptr [5 x i8], [5 x i8]* @.str.308, i64 0, i64 0
  %r421 = ptrtoint i8* %r420 to i64
  %r422 = call i64 @_get(i64 %r419, i64 %r421)
  %r423 = load i64, i64* @TOK_LPAREN
  %r424 = call i64 @_eq(i64 %r422, i64 %r423)
  %r425 = icmp ne i64 %r424, 0
  br i1 %r425, label %L927, label %L929
L927:
  %r426 = call i64 @parse_expr()
  store i64 %r426, i64* %ptr_expr
  %r427 = load i64, i64* @TOK_CARET
  %r428 = call i64 @expect(i64 %r427)
  %r429 = call i64 @_map_new()
  %r430 = getelementptr [5 x i8], [5 x i8]* @.str.309, i64 0, i64 0
  %r431 = ptrtoint i8* %r430 to i64
  %r432 = load i64, i64* @STMT_EXPR
  call i64 @_map_set(i64 %r429, i64 %r431, i64 %r432)
  %r433 = getelementptr [5 x i8], [5 x i8]* @.str.310, i64 0, i64 0
  %r434 = ptrtoint i8* %r433 to i64
  %r435 = load i64, i64* %ptr_expr
  call i64 @_map_set(i64 %r429, i64 %r434, i64 %r435)
  ret i64 %r429
  br label %L929
L929:
  br label %L908
L908:
  %r436 = load i64, i64* %ptr_t
  %r437 = getelementptr [5 x i8], [5 x i8]* @.str.311, i64 0, i64 0
  %r438 = ptrtoint i8* %r437 to i64
  %r439 = call i64 @_get(i64 %r436, i64 %r438)
  %r440 = load i64, i64* @TOK_EOF
  %r442 = call i64 @_eq(i64 %r439, i64 %r440)
  %r441 = xor i64 %r442, 1
  %r443 = icmp ne i64 %r441, 0
  br i1 %r443, label %L930, label %L932
L930:
  %r444 = call i64 @advance()
  br label %L932
L932:
  %r445 = call i64 @_map_new()
  %r446 = getelementptr [5 x i8], [5 x i8]* @.str.312, i64 0, i64 0
  %r447 = ptrtoint i8* %r446 to i64
  %r448 = sub i64 0, 1
  call i64 @_map_set(i64 %r445, i64 %r447, i64 %r448)
  ret i64 %r445
  ret i64 0
}
define i64 @eval_expr(i64 %arg_node) {
  %ptr_node = alloca i64
  store i64 %arg_node, i64* %ptr_node
  %ptr_op = alloca i64
  %ptr_left = alloca i64
  %ptr_right = alloca i64
  %r1 = load i64, i64* %ptr_node
  %r2 = getelementptr [5 x i8], [5 x i8]* @.str.313, i64 0, i64 0
  %r3 = ptrtoint i8* %r2 to i64
  %r4 = call i64 @_get(i64 %r1, i64 %r3)
  %r5 = load i64, i64* @EXPR_INT
  %r6 = call i64 @_eq(i64 %r4, i64 %r5)
  %r7 = icmp ne i64 %r6, 0
  br i1 %r7, label %L933, label %L935
L933:
  %r8 = load i64, i64* %ptr_node
  %r9 = getelementptr [4 x i8], [4 x i8]* @.str.314, i64 0, i64 0
  %r10 = ptrtoint i8* %r9 to i64
  %r11 = call i64 @_get(i64 %r8, i64 %r10)
  %r12 = call i64 @str_to_int(i64 %r11)
  ret i64 %r12
  br label %L935
L935:
  %r13 = load i64, i64* %ptr_node
  %r14 = getelementptr [5 x i8], [5 x i8]* @.str.315, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  %r16 = call i64 @_get(i64 %r13, i64 %r15)
  %r17 = load i64, i64* @EXPR_STRING
  %r18 = call i64 @_eq(i64 %r16, i64 %r17)
  %r19 = icmp ne i64 %r18, 0
  br i1 %r19, label %L936, label %L938
L936:
  %r20 = load i64, i64* %ptr_node
  %r21 = getelementptr [4 x i8], [4 x i8]* @.str.316, i64 0, i64 0
  %r22 = ptrtoint i8* %r21 to i64
  %r23 = call i64 @_get(i64 %r20, i64 %r22)
  ret i64 %r23
  br label %L938
L938:
  %r24 = load i64, i64* %ptr_node
  %r25 = getelementptr [5 x i8], [5 x i8]* @.str.317, i64 0, i64 0
  %r26 = ptrtoint i8* %r25 to i64
  %r27 = call i64 @_get(i64 %r24, i64 %r26)
  %r28 = load i64, i64* @EXPR_VAR
  %r29 = call i64 @_eq(i64 %r27, i64 %r28)
  %r30 = icmp ne i64 %r29, 0
  br i1 %r30, label %L939, label %L941
L939:
  %r31 = load i64, i64* @runtime_env
  %r32 = load i64, i64* %ptr_node
  %r33 = getelementptr [5 x i8], [5 x i8]* @.str.318, i64 0, i64 0
  %r34 = ptrtoint i8* %r33 to i64
  %r35 = call i64 @_get(i64 %r32, i64 %r34)
  %r36 = call i64 @_get(i64 %r31, i64 %r35)
  ret i64 %r36
  br label %L941
L941:
  %r37 = load i64, i64* %ptr_node
  %r38 = getelementptr [5 x i8], [5 x i8]* @.str.319, i64 0, i64 0
  %r39 = ptrtoint i8* %r38 to i64
  %r40 = call i64 @_get(i64 %r37, i64 %r39)
  %r41 = load i64, i64* @EXPR_BINARY
  %r42 = call i64 @_eq(i64 %r40, i64 %r41)
  %r43 = icmp ne i64 %r42, 0
  br i1 %r43, label %L942, label %L944
L942:
  %r44 = load i64, i64* %ptr_node
  %r45 = getelementptr [3 x i8], [3 x i8]* @.str.320, i64 0, i64 0
  %r46 = ptrtoint i8* %r45 to i64
  %r47 = call i64 @_get(i64 %r44, i64 %r46)
  store i64 %r47, i64* %ptr_op
  %r48 = load i64, i64* %ptr_node
  %r49 = getelementptr [5 x i8], [5 x i8]* @.str.321, i64 0, i64 0
  %r50 = ptrtoint i8* %r49 to i64
  %r51 = call i64 @_get(i64 %r48, i64 %r50)
  %r52 = call i64 @eval_expr(i64 %r51)
  store i64 %r52, i64* %ptr_left
  %r53 = load i64, i64* %ptr_node
  %r54 = getelementptr [6 x i8], [6 x i8]* @.str.322, i64 0, i64 0
  %r55 = ptrtoint i8* %r54 to i64
  %r56 = call i64 @_get(i64 %r53, i64 %r55)
  %r57 = call i64 @eval_expr(i64 %r56)
  store i64 %r57, i64* %ptr_right
  %r58 = load i64, i64* %ptr_op
  %r59 = getelementptr [2 x i8], [2 x i8]* @.str.323, i64 0, i64 0
  %r60 = ptrtoint i8* %r59 to i64
  %r61 = call i64 @_eq(i64 %r58, i64 %r60)
  %r62 = icmp ne i64 %r61, 0
  br i1 %r62, label %L945, label %L947
L945:
  %r63 = load i64, i64* %ptr_left
  %r64 = load i64, i64* %ptr_right
  %r65 = call i64 @_add(i64 %r63, i64 %r64)
  ret i64 %r65
  br label %L947
L947:
  %r66 = load i64, i64* %ptr_op
  %r67 = getelementptr [2 x i8], [2 x i8]* @.str.324, i64 0, i64 0
  %r68 = ptrtoint i8* %r67 to i64
  %r69 = call i64 @_eq(i64 %r66, i64 %r68)
  %r70 = icmp ne i64 %r69, 0
  br i1 %r70, label %L948, label %L950
L948:
  %r71 = load i64, i64* %ptr_left
  %r72 = load i64, i64* %ptr_right
  %r73 = sub i64 %r71, %r72
  ret i64 %r73
  br label %L950
L950:
  %r74 = load i64, i64* %ptr_op
  %r75 = getelementptr [2 x i8], [2 x i8]* @.str.325, i64 0, i64 0
  %r76 = ptrtoint i8* %r75 to i64
  %r77 = call i64 @_eq(i64 %r74, i64 %r76)
  %r78 = icmp ne i64 %r77, 0
  br i1 %r78, label %L951, label %L953
L951:
  %r79 = load i64, i64* %ptr_left
  %r80 = load i64, i64* %ptr_right
  %r81 = mul i64 %r79, %r80
  ret i64 %r81
  br label %L953
L953:
  %r82 = load i64, i64* %ptr_op
  %r83 = getelementptr [2 x i8], [2 x i8]* @.str.326, i64 0, i64 0
  %r84 = ptrtoint i8* %r83 to i64
  %r85 = call i64 @_eq(i64 %r82, i64 %r84)
  %r86 = icmp ne i64 %r85, 0
  br i1 %r86, label %L954, label %L956
L954:
  %r87 = load i64, i64* %ptr_left
  %r88 = load i64, i64* %ptr_right
  %r89 = sdiv i64 %r87, %r88
  ret i64 %r89
  br label %L956
L956:
  %r90 = load i64, i64* %ptr_op
  %r91 = getelementptr [2 x i8], [2 x i8]* @.str.327, i64 0, i64 0
  %r92 = ptrtoint i8* %r91 to i64
  %r93 = call i64 @_eq(i64 %r90, i64 %r92)
  %r94 = icmp ne i64 %r93, 0
  br i1 %r94, label %L957, label %L959
L957:
  %r95 = load i64, i64* %ptr_left
  %r96 = load i64, i64* %ptr_right
  %r98 = icmp slt i64 %r95, %r96
  %r97 = zext i1 %r98 to i64
  %r99 = icmp ne i64 %r97, 0
  br i1 %r99, label %L960, label %L962
L960:
  ret i64 1
  br label %L962
L962:
  ret i64 0
  br label %L959
L959:
  %r100 = load i64, i64* %ptr_op
  %r101 = getelementptr [2 x i8], [2 x i8]* @.str.328, i64 0, i64 0
  %r102 = ptrtoint i8* %r101 to i64
  %r103 = call i64 @_eq(i64 %r100, i64 %r102)
  %r104 = icmp ne i64 %r103, 0
  br i1 %r104, label %L963, label %L965
L963:
  %r105 = load i64, i64* %ptr_left
  %r106 = load i64, i64* %ptr_right
  %r108 = icmp sgt i64 %r105, %r106
  %r107 = zext i1 %r108 to i64
  %r109 = icmp ne i64 %r107, 0
  br i1 %r109, label %L966, label %L968
L966:
  ret i64 1
  br label %L968
L968:
  ret i64 0
  br label %L965
L965:
  %r110 = load i64, i64* %ptr_op
  %r111 = getelementptr [3 x i8], [3 x i8]* @.str.329, i64 0, i64 0
  %r112 = ptrtoint i8* %r111 to i64
  %r113 = call i64 @_eq(i64 %r110, i64 %r112)
  %r114 = icmp ne i64 %r113, 0
  br i1 %r114, label %L969, label %L971
L969:
  %r115 = load i64, i64* %ptr_left
  %r116 = load i64, i64* %ptr_right
  %r117 = call i64 @_eq(i64 %r115, i64 %r116)
  %r118 = icmp ne i64 %r117, 0
  br i1 %r118, label %L972, label %L974
L972:
  ret i64 1
  br label %L974
L974:
  ret i64 0
  br label %L971
L971:
  br label %L944
L944:
  ret i64 0
  ret i64 0
}
define i64 @eval_stmt(i64 %arg_node) {
  %ptr_node = alloca i64
  store i64 %arg_node, i64* %ptr_node
  %ptr_out_val = alloca i64
  %ptr_out_str = alloca i64
  %ptr_cond = alloca i64
  %ptr_i = alloca i64
  %r1 = load i64, i64* %ptr_node
  %r2 = getelementptr [5 x i8], [5 x i8]* @.str.331, i64 0, i64 0
  %r3 = ptrtoint i8* %r2 to i64
  %r4 = call i64 @_get(i64 %r1, i64 %r3)
  %r5 = load i64, i64* @STMT_LET
  %r6 = call i64 @_eq(i64 %r4, i64 %r5)
  store i64 1, i64* @.sc.330
  %r8 = icmp eq i64 %r6, 0
  br i1 %r8, label %L975, label %L976
L975:
  %r9 = load i64, i64* %ptr_node
  %r10 = getelementptr [5 x i8], [5 x i8]* @.str.332, i64 0, i64 0
  %r11 = ptrtoint i8* %r10 to i64
  %r12 = call i64 @_get(i64 %r9, i64 %r11)
  %r13 = load i64, i64* @STMT_ASSIGN
  %r14 = call i64 @_eq(i64 %r12, i64 %r13)
  %r15 = icmp ne i64 %r14, 0
  %r16 = zext i1 %r15 to i64
  store i64 %r16, i64* @.sc.330
  br label %L976
L976:
  %r7 = load i64, i64* @.sc.330
  %r17 = icmp ne i64 %r7, 0
  br i1 %r17, label %L977, label %L978
L977:
  %r18 = load i64, i64* %ptr_node
  %r19 = getelementptr [4 x i8], [4 x i8]* @.str.333, i64 0, i64 0
  %r20 = ptrtoint i8* %r19 to i64
  %r21 = call i64 @_get(i64 %r18, i64 %r20)
  %r22 = call i64 @eval_expr(i64 %r21)
  %r23 = load i64, i64* %ptr_node
  %r24 = getelementptr [5 x i8], [5 x i8]* @.str.334, i64 0, i64 0
  %r25 = ptrtoint i8* %r24 to i64
  %r26 = call i64 @_get(i64 %r23, i64 %r25)
  %r27 = load i64, i64* @runtime_env
  call i64 @_set(i64 %r27, i64 %r26, i64 %r22)
  br label %L979
L978:
  %r28 = load i64, i64* %ptr_node
  %r29 = getelementptr [5 x i8], [5 x i8]* @.str.335, i64 0, i64 0
  %r30 = ptrtoint i8* %r29 to i64
  %r31 = call i64 @_get(i64 %r28, i64 %r30)
  %r32 = load i64, i64* @STMT_PRINT
  %r33 = call i64 @_eq(i64 %r31, i64 %r32)
  %r34 = icmp ne i64 %r33, 0
  br i1 %r34, label %L980, label %L981
L980:
  %r35 = load i64, i64* %ptr_node
  %r36 = getelementptr [4 x i8], [4 x i8]* @.str.336, i64 0, i64 0
  %r37 = ptrtoint i8* %r36 to i64
  %r38 = call i64 @_get(i64 %r35, i64 %r37)
  %r39 = call i64 @eval_expr(i64 %r38)
  store i64 %r39, i64* %ptr_out_val
  %r40 = getelementptr [1 x i8], [1 x i8]* @.str.337, i64 0, i64 0
  %r41 = ptrtoint i8* %r40 to i64
  %r42 = load i64, i64* %ptr_out_val
  %r43 = call i64 @_add(i64 %r41, i64 %r42)
  store i64 %r43, i64* %ptr_out_str
  %r44 = load i64, i64* @eval_terminal
  %r45 = getelementptr [5 x i8], [5 x i8]* @.str.338, i64 0, i64 0
  %r46 = ptrtoint i8* %r45 to i64
  %r47 = load i64, i64* %ptr_out_str
  %r48 = call i64 @_add(i64 %r46, i64 %r47)
  %r49 = getelementptr [2 x i8], [2 x i8]* @.str.339, i64 0, i64 0
  %r50 = ptrtoint i8* %r49 to i64
  %r51 = call i64 @_add(i64 %r48, i64 %r50)
  %r52 = call i64 @send_msg(i64 %r44, i64 %r51)
  br label %L982
L981:
  %r53 = load i64, i64* %ptr_node
  %r54 = getelementptr [5 x i8], [5 x i8]* @.str.340, i64 0, i64 0
  %r55 = ptrtoint i8* %r54 to i64
  %r56 = call i64 @_get(i64 %r53, i64 %r55)
  %r57 = load i64, i64* @STMT_IF
  %r58 = call i64 @_eq(i64 %r56, i64 %r57)
  %r59 = icmp ne i64 %r58, 0
  br i1 %r59, label %L983, label %L984
L983:
  %r60 = load i64, i64* %ptr_node
  %r61 = getelementptr [5 x i8], [5 x i8]* @.str.341, i64 0, i64 0
  %r62 = ptrtoint i8* %r61 to i64
  %r63 = call i64 @_get(i64 %r60, i64 %r62)
  %r64 = call i64 @eval_expr(i64 %r63)
  store i64 %r64, i64* %ptr_cond
  %r65 = load i64, i64* %ptr_cond
  %r67 = call i64 @_eq(i64 %r65, i64 0)
  %r66 = xor i64 %r67, 1
  %r68 = icmp ne i64 %r66, 0
  br i1 %r68, label %L986, label %L987
L986:
  store i64 0, i64* %ptr_i
  br label %L989
L989:
  %r69 = load i64, i64* %ptr_i
  %r70 = load i64, i64* %ptr_node
  %r71 = getelementptr [5 x i8], [5 x i8]* @.str.342, i64 0, i64 0
  %r72 = ptrtoint i8* %r71 to i64
  %r73 = call i64 @_get(i64 %r70, i64 %r72)
  %r74 = call i64 @mensura(i64 %r73)
  %r76 = icmp slt i64 %r69, %r74
  %r75 = zext i1 %r76 to i64
  %r77 = icmp ne i64 %r75, 0
  br i1 %r77, label %L990, label %L991
L990:
  %r78 = load i64, i64* %ptr_node
  %r79 = getelementptr [5 x i8], [5 x i8]* @.str.343, i64 0, i64 0
  %r80 = ptrtoint i8* %r79 to i64
  %r81 = call i64 @_get(i64 %r78, i64 %r80)
  %r82 = load i64, i64* %ptr_i
  %r83 = call i64 @_get(i64 %r81, i64 %r82)
  %r84 = call i64 @eval_stmt(i64 %r83)
  %r85 = load i64, i64* %ptr_i
  %r86 = call i64 @_add(i64 %r85, i64 1)
  store i64 %r86, i64* %ptr_i
  br label %L989
L991:
  br label %L988
L987:
  %r87 = load i64, i64* %ptr_node
  %r88 = getelementptr [5 x i8], [5 x i8]* @.str.344, i64 0, i64 0
  %r89 = ptrtoint i8* %r88 to i64
  %r90 = call i64 @_get(i64 %r87, i64 %r89)
  %r91 = call i64 @mensura(i64 %r90)
  %r93 = icmp sgt i64 %r91, 0
  %r92 = zext i1 %r93 to i64
  %r94 = icmp ne i64 %r92, 0
  br i1 %r94, label %L992, label %L994
L992:
  store i64 0, i64* %ptr_i
  br label %L995
L995:
  %r95 = load i64, i64* %ptr_i
  %r96 = load i64, i64* %ptr_node
  %r97 = getelementptr [5 x i8], [5 x i8]* @.str.345, i64 0, i64 0
  %r98 = ptrtoint i8* %r97 to i64
  %r99 = call i64 @_get(i64 %r96, i64 %r98)
  %r100 = call i64 @mensura(i64 %r99)
  %r102 = icmp slt i64 %r95, %r100
  %r101 = zext i1 %r102 to i64
  %r103 = icmp ne i64 %r101, 0
  br i1 %r103, label %L996, label %L997
L996:
  %r104 = load i64, i64* %ptr_node
  %r105 = getelementptr [5 x i8], [5 x i8]* @.str.346, i64 0, i64 0
  %r106 = ptrtoint i8* %r105 to i64
  %r107 = call i64 @_get(i64 %r104, i64 %r106)
  %r108 = load i64, i64* %ptr_i
  %r109 = call i64 @_get(i64 %r107, i64 %r108)
  %r110 = call i64 @eval_stmt(i64 %r109)
  %r111 = load i64, i64* %ptr_i
  %r112 = call i64 @_add(i64 %r111, i64 1)
  store i64 %r112, i64* %ptr_i
  br label %L995
L997:
  br label %L994
L994:
  br label %L988
L988:
  br label %L985
L984:
  %r113 = load i64, i64* %ptr_node
  %r114 = getelementptr [5 x i8], [5 x i8]* @.str.347, i64 0, i64 0
  %r115 = ptrtoint i8* %r114 to i64
  %r116 = call i64 @_get(i64 %r113, i64 %r115)
  %r117 = load i64, i64* @STMT_WHILE
  %r118 = call i64 @_eq(i64 %r116, i64 %r117)
  %r119 = icmp ne i64 %r118, 0
  br i1 %r119, label %L998, label %L1000
L998:
  br label %L1001
L1001:
  %r120 = load i64, i64* %ptr_node
  %r121 = getelementptr [5 x i8], [5 x i8]* @.str.348, i64 0, i64 0
  %r122 = ptrtoint i8* %r121 to i64
  %r123 = call i64 @_get(i64 %r120, i64 %r122)
  %r124 = call i64 @eval_expr(i64 %r123)
  %r126 = call i64 @_eq(i64 %r124, i64 0)
  %r125 = xor i64 %r126, 1
  %r127 = icmp ne i64 %r125, 0
  br i1 %r127, label %L1002, label %L1003
L1002:
  store i64 0, i64* %ptr_i
  br label %L1004
L1004:
  %r128 = load i64, i64* %ptr_i
  %r129 = load i64, i64* %ptr_node
  %r130 = getelementptr [5 x i8], [5 x i8]* @.str.349, i64 0, i64 0
  %r131 = ptrtoint i8* %r130 to i64
  %r132 = call i64 @_get(i64 %r129, i64 %r131)
  %r133 = call i64 @mensura(i64 %r132)
  %r135 = icmp slt i64 %r128, %r133
  %r134 = zext i1 %r135 to i64
  %r136 = icmp ne i64 %r134, 0
  br i1 %r136, label %L1005, label %L1006
L1005:
  %r137 = load i64, i64* %ptr_node
  %r138 = getelementptr [5 x i8], [5 x i8]* @.str.350, i64 0, i64 0
  %r139 = ptrtoint i8* %r138 to i64
  %r140 = call i64 @_get(i64 %r137, i64 %r139)
  %r141 = load i64, i64* %ptr_i
  %r142 = call i64 @_get(i64 %r140, i64 %r141)
  %r143 = call i64 @eval_stmt(i64 %r142)
  %r144 = load i64, i64* %ptr_i
  %r145 = call i64 @_add(i64 %r144, i64 1)
  store i64 %r145, i64* %ptr_i
  br label %L1004
L1006:
  br label %L1001
L1003:
  br label %L1000
L1000:
  br label %L985
L985:
  br label %L982
L982:
  br label %L979
L979:
  ret i64 0
}
define i64 @execute_achlys_script(i64 %arg_term_idx, i64 %arg_src) {
  %ptr_term_idx = alloca i64
  store i64 %arg_term_idx, i64* %ptr_term_idx
  %ptr_src = alloca i64
  store i64 %arg_src, i64* %ptr_src
  %ptr_stmts = alloca i64
  %ptr_pt = alloca i64
  %ptr_i = alloca i64
  %r1 = load i64, i64* %ptr_term_idx
  store i64 %r1, i64* @eval_terminal
  %r2 = call i64 @_map_new()
  store i64 %r2, i64* @runtime_env
  %r3 = load i64, i64* %ptr_src
  %r4 = call i64 @lex_source(i64 %r3)
  store i64 %r4, i64* @global_tokens
  store i64 0, i64* @p_pos
  %r5 = call i64 @_list_new()
  store i64 %r5, i64* %ptr_stmts
  %r6 = call i64 @peek()
  store i64 %r6, i64* %ptr_pt
  br label %L1007
L1007:
  %r7 = load i64, i64* %ptr_pt
  %r8 = getelementptr [5 x i8], [5 x i8]* @.str.351, i64 0, i64 0
  %r9 = ptrtoint i8* %r8 to i64
  %r10 = call i64 @_get(i64 %r7, i64 %r9)
  %r11 = load i64, i64* @TOK_EOF
  %r13 = call i64 @_eq(i64 %r10, i64 %r11)
  %r12 = xor i64 %r13, 1
  %r14 = icmp ne i64 %r12, 0
  br i1 %r14, label %L1008, label %L1009
L1008:
  %r15 = load i64, i64* %ptr_pt
  %r16 = getelementptr [5 x i8], [5 x i8]* @.str.352, i64 0, i64 0
  %r17 = ptrtoint i8* %r16 to i64
  %r18 = call i64 @_get(i64 %r15, i64 %r17)
  %r19 = load i64, i64* @TOK_CARET
  %r20 = call i64 @_eq(i64 %r18, i64 %r19)
  %r21 = icmp ne i64 %r20, 0
  br i1 %r21, label %L1010, label %L1012
L1010:
  %r22 = call i64 @advance()
  br label %L1007
L1012:
  %r23 = call i64 @parse_stmt()
  %r24 = load i64, i64* %ptr_stmts
  call i64 @_append_poly(i64 %r24, i64 %r23)
  %r25 = call i64 @peek()
  store i64 %r25, i64* %ptr_pt
  br label %L1007
L1009:
  %r26 = load i64, i64* @eval_terminal
  %r27 = getelementptr [42 x i8], [42 x i8]* @.str.353, i64 0, i64 0
  %r28 = ptrtoint i8* %r27 to i64
  %r29 = call i64 @send_msg(i64 %r26, i64 %r28)
  store i64 0, i64* %ptr_i
  br label %L1013
L1013:
  %r30 = load i64, i64* %ptr_i
  %r31 = load i64, i64* %ptr_stmts
  %r32 = call i64 @mensura(i64 %r31)
  %r34 = icmp slt i64 %r30, %r32
  %r33 = zext i1 %r34 to i64
  %r35 = icmp ne i64 %r33, 0
  br i1 %r35, label %L1014, label %L1015
L1014:
  %r36 = load i64, i64* %ptr_stmts
  %r37 = load i64, i64* %ptr_i
  %r38 = call i64 @_get(i64 %r36, i64 %r37)
  %r39 = call i64 @eval_stmt(i64 %r38)
  %r40 = load i64, i64* %ptr_i
  %r41 = call i64 @_add(i64 %r40, i64 1)
  store i64 %r41, i64* %ptr_i
  br label %L1013
L1015:
  %r42 = load i64, i64* @eval_terminal
  %r43 = getelementptr [28 x i8], [28 x i8]* @.str.354, i64 0, i64 0
  %r44 = ptrtoint i8* %r43 to i64
  %r45 = call i64 @send_msg(i64 %r42, i64 %r44)
  ret i64 0
}
define i64 @apply_layout() {
  %ptr_n = alloca i64
  %ptr_c = alloca i64
  %ptr_gap = alloca i64
  %ptr_margin = alloca i64
  %ptr_ob_h = alloca i64
  %ptr_work_w = alloca i64
  %ptr_work_h = alloca i64
  %ptr_cx = alloca i64
  %ptr_cy = alloca i64
  %ptr_start_y = alloca i64
  %ptr_start_x = alloca i64
  %ptr_left_count = alloca i64
  %ptr_right_count = alloca i64
  %ptr_col_w = alloca i64
  %ptr_l_idx = alloca i64
  %ptr_r_idx = alloca i64
  %ptr_i = alloca i64
  %ptr_left_h = alloca i64
  %ptr_right_h = alloca i64
  store i64 0, i64* %ptr_n
  store i64 0, i64* %ptr_c
  br label %L1016
L1016:
  %r1 = load i64, i64* %ptr_c
  %r2 = load i64, i64* @actor_x
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp slt i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L1017, label %L1018
L1017:
  %r7 = load i64, i64* @actor_app
  %r8 = load i64, i64* %ptr_c
  %r9 = call i64 @_get(i64 %r7, i64 %r8)
  %r10 = sub i64 0, 1
  %r12 = call i64 @_eq(i64 %r9, i64 %r10)
  %r11 = xor i64 %r12, 1
  %r13 = icmp ne i64 %r11, 0
  br i1 %r13, label %L1019, label %L1021
L1019:
  %r14 = load i64, i64* %ptr_n
  %r15 = call i64 @_add(i64 %r14, i64 1)
  store i64 %r15, i64* %ptr_n
  br label %L1021
L1021:
  %r16 = load i64, i64* %ptr_c
  %r17 = call i64 @_add(i64 %r16, i64 1)
  store i64 %r17, i64* %ptr_c
  br label %L1016
L1018:
  %r18 = load i64, i64* %ptr_n
  %r19 = call i64 @_eq(i64 %r18, i64 0)
  %r20 = icmp ne i64 %r19, 0
  br i1 %r20, label %L1022, label %L1024
L1022:
  ret i64 0
  br label %L1024
L1024:
  store i64 15, i64* %ptr_gap
  store i64 20, i64* %ptr_margin
  store i64 40, i64* %ptr_ob_h
  %r21 = load i64, i64* @FB_WIDTH
  %r22 = load i64, i64* %ptr_margin
  %r23 = mul i64 %r22, 2
  %r24 = sub i64 %r21, %r23
  store i64 %r24, i64* %ptr_work_w
  %r25 = load i64, i64* @FB_HEIGHT
  %r26 = load i64, i64* %ptr_ob_h
  %r27 = sub i64 %r25, %r26
  %r28 = load i64, i64* %ptr_margin
  %r29 = mul i64 %r28, 3
  %r30 = sub i64 %r27, %r29
  store i64 %r30, i64* %ptr_work_h
  %r31 = load i64, i64* @FB_WIDTH
  %r32 = sdiv i64 %r31, 2
  store i64 %r32, i64* %ptr_cx
  %r33 = load i64, i64* @FB_HEIGHT
  %r34 = sdiv i64 %r33, 2
  store i64 %r34, i64* %ptr_cy
  %r35 = load i64, i64* %ptr_margin
  %r36 = load i64, i64* %ptr_cy
  %r37 = sub i64 %r35, %r36
  store i64 %r37, i64* %ptr_start_y
  %r38 = load i64, i64* %ptr_margin
  %r39 = load i64, i64* %ptr_cx
  %r40 = sub i64 %r38, %r39
  store i64 %r40, i64* %ptr_start_x
  %r41 = load i64, i64* %ptr_n
  %r42 = sdiv i64 %r41, 2
  %r43 = load i64, i64* %ptr_n
  %r44 = srem i64 %r43, 2
  %r45 = call i64 @_add(i64 %r42, i64 %r44)
  store i64 %r45, i64* %ptr_left_count
  %r46 = load i64, i64* %ptr_n
  %r47 = load i64, i64* %ptr_left_count
  %r48 = sub i64 %r46, %r47
  store i64 %r48, i64* %ptr_right_count
  %r49 = load i64, i64* %ptr_work_w
  %r50 = sdiv i64 %r49, 2
  %r51 = load i64, i64* %ptr_gap
  %r52 = sdiv i64 %r51, 2
  %r53 = sub i64 %r50, %r52
  store i64 %r53, i64* %ptr_col_w
  %r54 = load i64, i64* %ptr_n
  %r55 = call i64 @_eq(i64 %r54, i64 1)
  %r56 = icmp ne i64 %r55, 0
  br i1 %r56, label %L1025, label %L1027
L1025:
  %r57 = load i64, i64* %ptr_work_w
  store i64 %r57, i64* %ptr_col_w
  br label %L1027
L1027:
  store i64 0, i64* %ptr_l_idx
  store i64 0, i64* %ptr_r_idx
  store i64 0, i64* %ptr_i
  br label %L1028
L1028:
  %r58 = load i64, i64* %ptr_i
  %r59 = load i64, i64* @actor_x
  %r60 = call i64 @mensura(i64 %r59)
  %r62 = icmp slt i64 %r58, %r60
  %r61 = zext i1 %r62 to i64
  %r63 = icmp ne i64 %r61, 0
  br i1 %r63, label %L1029, label %L1030
L1029:
  %r64 = load i64, i64* @actor_app
  %r65 = load i64, i64* %ptr_i
  %r66 = call i64 @_get(i64 %r64, i64 %r65)
  %r67 = sub i64 0, 1
  %r69 = call i64 @_eq(i64 %r66, i64 %r67)
  %r68 = xor i64 %r69, 1
  %r70 = icmp ne i64 %r68, 0
  br i1 %r70, label %L1031, label %L1033
L1031:
  %r71 = load i64, i64* %ptr_l_idx
  %r72 = load i64, i64* %ptr_left_count
  %r74 = icmp slt i64 %r71, %r72
  %r73 = zext i1 %r74 to i64
  %r75 = icmp ne i64 %r73, 0
  br i1 %r75, label %L1034, label %L1035
L1034:
  %r76 = load i64, i64* %ptr_work_h
  %r77 = load i64, i64* %ptr_gap
  %r78 = load i64, i64* %ptr_left_count
  %r79 = sub i64 %r78, 1
  %r80 = mul i64 %r77, %r79
  %r81 = sub i64 %r76, %r80
  %r82 = load i64, i64* %ptr_left_count
  %r83 = sdiv i64 %r81, %r82
  store i64 %r83, i64* %ptr_left_h
  %r84 = load i64, i64* %ptr_n
  %r85 = call i64 @_eq(i64 %r84, i64 1)
  %r86 = icmp ne i64 %r85, 0
  br i1 %r86, label %L1037, label %L1039
L1037:
  %r87 = load i64, i64* %ptr_work_h
  store i64 %r87, i64* %ptr_left_h
  br label %L1039
L1039:
  %r88 = load i64, i64* %ptr_start_x
  %r89 = load i64, i64* %ptr_i
  %r90 = load i64, i64* @actor_x
  call i64 @_set(i64 %r90, i64 %r89, i64 %r88)
  %r91 = load i64, i64* %ptr_start_y
  %r92 = load i64, i64* %ptr_l_idx
  %r93 = load i64, i64* %ptr_left_h
  %r94 = load i64, i64* %ptr_gap
  %r95 = call i64 @_add(i64 %r93, i64 %r94)
  %r96 = mul i64 %r92, %r95
  %r97 = call i64 @_add(i64 %r91, i64 %r96)
  %r98 = load i64, i64* %ptr_i
  %r99 = load i64, i64* @actor_y
  call i64 @_set(i64 %r99, i64 %r98, i64 %r97)
  %r100 = load i64, i64* %ptr_col_w
  %r101 = load i64, i64* %ptr_i
  %r102 = load i64, i64* @actor_w
  call i64 @_set(i64 %r102, i64 %r101, i64 %r100)
  %r103 = load i64, i64* %ptr_left_h
  %r104 = load i64, i64* %ptr_i
  %r105 = load i64, i64* @actor_h
  call i64 @_set(i64 %r105, i64 %r104, i64 %r103)
  %r106 = load i64, i64* %ptr_l_idx
  %r107 = call i64 @_add(i64 %r106, i64 1)
  store i64 %r107, i64* %ptr_l_idx
  br label %L1036
L1035:
  %r108 = load i64, i64* %ptr_work_h
  %r109 = load i64, i64* %ptr_gap
  %r110 = load i64, i64* %ptr_right_count
  %r111 = sub i64 %r110, 1
  %r112 = mul i64 %r109, %r111
  %r113 = sub i64 %r108, %r112
  %r114 = load i64, i64* %ptr_right_count
  %r115 = sdiv i64 %r113, %r114
  store i64 %r115, i64* %ptr_right_h
  %r116 = load i64, i64* %ptr_start_x
  %r117 = load i64, i64* %ptr_col_w
  %r118 = call i64 @_add(i64 %r116, i64 %r117)
  %r119 = load i64, i64* %ptr_gap
  %r120 = call i64 @_add(i64 %r118, i64 %r119)
  %r121 = load i64, i64* %ptr_i
  %r122 = load i64, i64* @actor_x
  call i64 @_set(i64 %r122, i64 %r121, i64 %r120)
  %r123 = load i64, i64* %ptr_start_y
  %r124 = load i64, i64* %ptr_r_idx
  %r125 = load i64, i64* %ptr_right_h
  %r126 = load i64, i64* %ptr_gap
  %r127 = call i64 @_add(i64 %r125, i64 %r126)
  %r128 = mul i64 %r124, %r127
  %r129 = call i64 @_add(i64 %r123, i64 %r128)
  %r130 = load i64, i64* %ptr_i
  %r131 = load i64, i64* @actor_y
  call i64 @_set(i64 %r131, i64 %r130, i64 %r129)
  %r132 = load i64, i64* %ptr_col_w
  %r133 = load i64, i64* %ptr_i
  %r134 = load i64, i64* @actor_w
  call i64 @_set(i64 %r134, i64 %r133, i64 %r132)
  %r135 = load i64, i64* %ptr_right_h
  %r136 = load i64, i64* %ptr_i
  %r137 = load i64, i64* @actor_h
  call i64 @_set(i64 %r137, i64 %r136, i64 %r135)
  %r138 = load i64, i64* %ptr_r_idx
  %r139 = call i64 @_add(i64 %r138, i64 1)
  store i64 %r139, i64* %ptr_r_idx
  br label %L1036
L1036:
  br label %L1033
L1033:
  %r140 = load i64, i64* %ptr_i
  %r141 = call i64 @_add(i64 %r140, i64 1)
  store i64 %r141, i64* %ptr_i
  br label %L1028
L1030:
  ret i64 0
}
define i64 @rand() {
  %ptr_ret = alloca i64
  %r1 = load i64, i64* @rand_seed
  %r2 = mul i64 %r1, 1103515245
  %r3 = sub i64 0, 12345
  %r4 = sub i64 %r2, %r3
  store i64 %r4, i64* @rand_seed
  %r5 = load i64, i64* @rand_seed
  %r6 = srem i64 %r5, 2147483647
  store i64 %r6, i64* %ptr_ret
  %r7 = load i64, i64* %ptr_ret
  %r9 = icmp slt i64 %r7, 0
  %r8 = zext i1 %r9 to i64
  %r10 = icmp ne i64 %r8, 0
  br i1 %r10, label %L1040, label %L1042
L1040:
  %r11 = load i64, i64* %ptr_ret
  %r12 = sub i64 0, %r11
  store i64 %r12, i64* %ptr_ret
  br label %L1042
L1042:
  %r13 = load i64, i64* %ptr_ret
  ret i64 %r13
  ret i64 0
}
define i64 @init_particles() {
  %ptr_i = alloca i64
  store i64 0, i64* %ptr_i
  br label %L1043
L1043:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @MAX_PARTS
  %r4 = icmp slt i64 %r1, %r2
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L1044, label %L1045
L1044:
  %r6 = load i64, i64* @part_x
  call i64 @_append_poly(i64 %r6, i64 0)
  %r7 = load i64, i64* @part_y
  call i64 @_append_poly(i64 %r7, i64 0)
  %r8 = load i64, i64* @part_vx
  call i64 @_append_poly(i64 %r8, i64 0)
  %r9 = load i64, i64* @part_vy
  call i64 @_append_poly(i64 %r9, i64 0)
  %r10 = load i64, i64* @part_life
  call i64 @_append_poly(i64 %r10, i64 0)
  %r11 = load i64, i64* %ptr_i
  %r12 = call i64 @_add(i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_i
  br label %L1043
L1045:
  ret i64 0
}
define i64 @spawn_particles(i64 %arg_x, i64 %arg_y, i64 %arg_w, i64 %arg_h) {
  %ptr_x = alloca i64
  store i64 %arg_x, i64* %ptr_x
  %ptr_y = alloca i64
  store i64 %arg_y, i64* %ptr_y
  %ptr_w = alloca i64
  store i64 %arg_w, i64* %ptr_w
  %ptr_h = alloca i64
  store i64 %arg_h, i64* %ptr_h
  %ptr_safe_w = alloca i64
  %ptr_safe_h = alloca i64
  %ptr_c = alloca i64
  %ptr_p = alloca i64
  %r1 = load i64, i64* %ptr_w
  store i64 %r1, i64* %ptr_safe_w
  %r2 = load i64, i64* %ptr_safe_w
  %r4 = icmp sle i64 %r2, 0
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L1046, label %L1048
L1046:
  store i64 1, i64* %ptr_safe_w
  br label %L1048
L1048:
  %r6 = load i64, i64* %ptr_h
  store i64 %r6, i64* %ptr_safe_h
  %r7 = load i64, i64* %ptr_safe_h
  %r9 = icmp sle i64 %r7, 0
  %r8 = zext i1 %r9 to i64
  %r10 = icmp ne i64 %r8, 0
  br i1 %r10, label %L1049, label %L1051
L1049:
  store i64 1, i64* %ptr_safe_h
  br label %L1051
L1051:
  store i64 0, i64* %ptr_c
  store i64 0, i64* %ptr_p
  br label %L1052
L1052:
  %r11 = load i64, i64* %ptr_p
  %r12 = load i64, i64* @MAX_PARTS
  %r14 = icmp slt i64 %r11, %r12
  %r13 = zext i1 %r14 to i64
  store i64 0, i64* @.sc.355
  %r16 = icmp ne i64 %r13, 0
  br i1 %r16, label %L1055, label %L1056
L1055:
  %r17 = load i64, i64* %ptr_c
  %r19 = icmp slt i64 %r17, 40
  %r18 = zext i1 %r19 to i64
  %r20 = icmp ne i64 %r18, 0
  %r21 = zext i1 %r20 to i64
  store i64 %r21, i64* @.sc.355
  br label %L1056
L1056:
  %r15 = load i64, i64* @.sc.355
  %r22 = icmp ne i64 %r15, 0
  br i1 %r22, label %L1053, label %L1054
L1053:
  %r23 = load i64, i64* @part_life
  %r24 = load i64, i64* %ptr_p
  %r25 = call i64 @_get(i64 %r23, i64 %r24)
  %r27 = icmp sle i64 %r25, 0
  %r26 = zext i1 %r27 to i64
  %r28 = icmp ne i64 %r26, 0
  br i1 %r28, label %L1057, label %L1059
L1057:
  %r29 = load i64, i64* %ptr_x
  %r30 = call i64 @rand()
  %r31 = load i64, i64* %ptr_safe_w
  %r32 = srem i64 %r30, %r31
  %r33 = call i64 @_add(i64 %r29, i64 %r32)
  %r34 = load i64, i64* %ptr_p
  %r35 = load i64, i64* @part_x
  call i64 @_set(i64 %r35, i64 %r34, i64 %r33)
  %r36 = load i64, i64* %ptr_y
  %r37 = call i64 @rand()
  %r38 = load i64, i64* %ptr_safe_h
  %r39 = srem i64 %r37, %r38
  %r40 = call i64 @_add(i64 %r36, i64 %r39)
  %r41 = load i64, i64* %ptr_p
  %r42 = load i64, i64* @part_y
  call i64 @_set(i64 %r42, i64 %r41, i64 %r40)
  %r43 = call i64 @rand()
  %r44 = srem i64 %r43, 20
  %r45 = sub i64 %r44, 10
  %r46 = load i64, i64* %ptr_p
  %r47 = load i64, i64* @part_vx
  call i64 @_set(i64 %r47, i64 %r46, i64 %r45)
  %r48 = call i64 @rand()
  %r49 = srem i64 %r48, 20
  %r50 = sub i64 %r49, 15
  %r51 = load i64, i64* %ptr_p
  %r52 = load i64, i64* @part_vy
  call i64 @_set(i64 %r52, i64 %r51, i64 %r50)
  %r53 = call i64 @rand()
  %r54 = srem i64 %r53, 30
  %r55 = call i64 @_add(i64 30, i64 %r54)
  %r56 = load i64, i64* %ptr_p
  %r57 = load i64, i64* @part_life
  call i64 @_set(i64 %r57, i64 %r56, i64 %r55)
  %r58 = load i64, i64* %ptr_c
  %r59 = call i64 @_add(i64 %r58, i64 1)
  store i64 %r59, i64* %ptr_c
  br label %L1059
L1059:
  %r60 = load i64, i64* %ptr_p
  %r61 = call i64 @_add(i64 %r60, i64 1)
  store i64 %r61, i64* %ptr_p
  br label %L1052
L1054:
  ret i64 0
}
define i64 @render_particles() {
  %ptr_i = alloca i64
  %ptr_is_active = alloca i64
  %ptr_sx = alloca i64
  %ptr_sy = alloca i64
  %ptr_sw = alloca i64
  store i64 0, i64* %ptr_i
  store i64 0, i64* %ptr_is_active
  br label %L1060
L1060:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @MAX_PARTS
  %r4 = icmp slt i64 %r1, %r2
  %r3 = zext i1 %r4 to i64
  %r5 = icmp ne i64 %r3, 0
  br i1 %r5, label %L1061, label %L1062
L1061:
  %r6 = load i64, i64* @part_life
  %r7 = load i64, i64* %ptr_i
  %r8 = call i64 @_get(i64 %r6, i64 %r7)
  %r10 = icmp sgt i64 %r8, 0
  %r9 = zext i1 %r10 to i64
  %r11 = icmp ne i64 %r9, 0
  br i1 %r11, label %L1063, label %L1065
L1063:
  %r12 = load i64, i64* @part_x
  %r13 = load i64, i64* %ptr_i
  %r14 = call i64 @_get(i64 %r12, i64 %r13)
  %r15 = load i64, i64* @part_vx
  %r16 = load i64, i64* %ptr_i
  %r17 = call i64 @_get(i64 %r15, i64 %r16)
  %r18 = call i64 @_add(i64 %r14, i64 %r17)
  %r19 = load i64, i64* %ptr_i
  %r20 = load i64, i64* @part_x
  call i64 @_set(i64 %r20, i64 %r19, i64 %r18)
  %r21 = load i64, i64* @part_y
  %r22 = load i64, i64* %ptr_i
  %r23 = call i64 @_get(i64 %r21, i64 %r22)
  %r24 = load i64, i64* @part_vy
  %r25 = load i64, i64* %ptr_i
  %r26 = call i64 @_get(i64 %r24, i64 %r25)
  %r27 = call i64 @_add(i64 %r23, i64 %r26)
  %r28 = load i64, i64* %ptr_i
  %r29 = load i64, i64* @part_y
  call i64 @_set(i64 %r29, i64 %r28, i64 %r27)
  %r30 = load i64, i64* @part_vy
  %r31 = load i64, i64* %ptr_i
  %r32 = call i64 @_get(i64 %r30, i64 %r31)
  %r33 = call i64 @_add(i64 %r32, i64 1)
  %r34 = load i64, i64* %ptr_i
  %r35 = load i64, i64* @part_vy
  call i64 @_set(i64 %r35, i64 %r34, i64 %r33)
  %r36 = load i64, i64* @part_life
  %r37 = load i64, i64* %ptr_i
  %r38 = call i64 @_get(i64 %r36, i64 %r37)
  %r39 = sub i64 %r38, 1
  %r40 = load i64, i64* %ptr_i
  %r41 = load i64, i64* @part_life
  call i64 @_set(i64 %r41, i64 %r40, i64 %r39)
  %r42 = load i64, i64* @part_x
  %r43 = load i64, i64* %ptr_i
  %r44 = call i64 @_get(i64 %r42, i64 %r43)
  %r45 = call i64 @world_to_screen_x(i64 %r44)
  store i64 %r45, i64* %ptr_sx
  %r46 = load i64, i64* @part_y
  %r47 = load i64, i64* %ptr_i
  %r48 = call i64 @_get(i64 %r46, i64 %r47)
  %r49 = call i64 @world_to_screen_y(i64 %r48)
  store i64 %r49, i64* %ptr_sy
  %r50 = call i64 @scale_size(i64 4)
  store i64 %r50, i64* %ptr_sw
  %r51 = load i64, i64* %ptr_sw
  %r53 = icmp slt i64 %r51, 1
  %r52 = zext i1 %r53 to i64
  %r54 = icmp ne i64 %r52, 0
  br i1 %r54, label %L1066, label %L1068
L1066:
  store i64 1, i64* %ptr_sw
  br label %L1068
L1068:
  %r55 = load i64, i64* %ptr_sx
  %r56 = load i64, i64* %ptr_sy
  %r57 = load i64, i64* %ptr_sw
  %r58 = load i64, i64* %ptr_sw
  %r59 = call i64 @draw_rect(i64 %r55, i64 %r56, i64 %r57, i64 %r58, i64 0, i64 255, i64 255)
  store i64 1, i64* %ptr_is_active
  br label %L1065
L1065:
  %r60 = load i64, i64* %ptr_i
  %r61 = call i64 @_add(i64 %r60, i64 1)
  store i64 %r61, i64* %ptr_i
  br label %L1060
L1062:
  %r62 = load i64, i64* %ptr_is_active
  ret i64 %r62
  ret i64 0
}
define i64 @achlys_panic(i64 %arg_err) {
  %ptr_err = alloca i64
  store i64 %arg_err, i64* %ptr_err
  %ptr_err_msg = alloca i64
  %r1 = load i64, i64* @FB_WIDTH
  %r2 = load i64, i64* @FB_HEIGHT
  %r3 = call i64 @draw_rect(i64 0, i64 0, i64 %r1, i64 %r2, i64 200, i64 0, i64 0)
  %r4 = load i64, i64* @FB_WIDTH
  %r5 = call i64 @draw_rect(i64 0, i64 350, i64 %r4, i64 68, i64 255, i64 255, i64 255)
  %r6 = getelementptr [20 x i8], [20 x i8]* @.str.356, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  store i64 %r7, i64* %ptr_err_msg
  %r8 = load i64, i64* @FB_WIDTH
  %r9 = sdiv i64 %r8, 2
  %r10 = sub i64 %r9, 200
  %r11 = load i64, i64* %ptr_err_msg
  %r12 = load i64, i64* %ptr_err
  %r13 = call i64 @int_to_str(i64 %r12)
  %r14 = call i64 @_add(i64 %r11, i64 %r13)
  %r15 = call i64 @draw_raw_string(i64 %r10, i64 375, i64 2, i64 %r14, i64 255, i64 0, i64 0)
  %r16 = call i64 @swap_buffers()
  br label %L1069
L1069:
  %r17 = icmp ne i64 1, 0
  br i1 %r17, label %L1070, label %L1071
L1070:
  br label %L1069
L1071:
  ret i64 0
}
define i64 @str_to_int(i64 %arg_s) {
  %ptr_s = alloca i64
  store i64 %arg_s, i64* %ptr_s
  %ptr_len = alloca i64
  %ptr_val = alloca i64
  %ptr_i = alloca i64
  %ptr_c = alloca i64
  %r1 = load i64, i64* %ptr_s
  %r2 = call i64 @mensura(i64 %r1)
  store i64 %r2, i64* %ptr_len
  store i64 0, i64* %ptr_val
  store i64 0, i64* %ptr_i
  br label %L1072
L1072:
  %r3 = load i64, i64* %ptr_i
  %r4 = load i64, i64* %ptr_len
  %r6 = icmp slt i64 %r3, %r4
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L1073, label %L1074
L1073:
  %r8 = load i64, i64* %ptr_s
  %r9 = load i64, i64* %ptr_i
  %r10 = call i64 @pars(i64 %r8, i64 %r9, i64 1)
  %r11 = call i64 @codex(i64 %r10)
  store i64 %r11, i64* %ptr_c
  %r12 = load i64, i64* %ptr_c
  %r14 = icmp sge i64 %r12, 48
  %r13 = zext i1 %r14 to i64
  store i64 0, i64* @.sc.357
  %r16 = icmp ne i64 %r13, 0
  br i1 %r16, label %L1075, label %L1076
L1075:
  %r17 = load i64, i64* %ptr_c
  %r19 = icmp sle i64 %r17, 57
  %r18 = zext i1 %r19 to i64
  %r20 = icmp ne i64 %r18, 0
  %r21 = zext i1 %r20 to i64
  store i64 %r21, i64* @.sc.357
  br label %L1076
L1076:
  %r15 = load i64, i64* @.sc.357
  %r22 = icmp ne i64 %r15, 0
  br i1 %r22, label %L1077, label %L1079
L1077:
  %r23 = load i64, i64* %ptr_val
  %r24 = mul i64 %r23, 10
  %r25 = load i64, i64* %ptr_c
  %r26 = sub i64 %r25, 48
  %r27 = call i64 @_add(i64 %r24, i64 %r26)
  store i64 %r27, i64* %ptr_val
  br label %L1079
L1079:
  %r28 = load i64, i64* %ptr_i
  %r29 = call i64 @_add(i64 %r28, i64 1)
  store i64 %r29, i64* %ptr_i
  br label %L1072
L1074:
  %r30 = load i64, i64* %ptr_val
  ret i64 %r30
  ret i64 0
}
define i64 @sys_exec(i64 %arg_node_idx, i64 %arg_code) {
  %ptr_node_idx = alloca i64
  store i64 %arg_node_idx, i64* %ptr_node_idx
  %ptr_code = alloca i64
  store i64 %arg_code, i64* %ptr_code
  %ptr_lines = alloca i64
  %ptr_cur = alloca i64
  %ptr_i = alloca i64
  %ptr_c = alloca i64
  %ptr_regs = alloca i64
  %ptr_pc = alloca i64
  %ptr_limit = alloca i64
  %ptr_cycles = alloca i64
  %ptr_line = alloca i64
  %ptr_l_len = alloca i64
  %ptr_r_idx = alloca i64
  %ptr_rest = alloca i64
  %ptr_sp = alloca i64
  %ptr_j = alloca i64
  %ptr_cmp_v = alloca i64
  %ptr_targ = alloca i64
  %r1 = call i64 @_list_new()
  store i64 %r1, i64* %ptr_lines
  %r2 = getelementptr [1 x i8], [1 x i8]* @.str.358, i64 0, i64 0
  %r3 = ptrtoint i8* %r2 to i64
  store i64 %r3, i64* %ptr_cur
  store i64 0, i64* %ptr_i
  br label %L1080
L1080:
  %r4 = load i64, i64* %ptr_i
  %r5 = load i64, i64* %ptr_code
  %r6 = call i64 @mensura(i64 %r5)
  %r8 = icmp slt i64 %r4, %r6
  %r7 = zext i1 %r8 to i64
  %r9 = icmp ne i64 %r7, 0
  br i1 %r9, label %L1081, label %L1082
L1081:
  %r10 = load i64, i64* %ptr_code
  %r11 = load i64, i64* %ptr_i
  %r12 = call i64 @pars(i64 %r10, i64 %r11, i64 1)
  store i64 %r12, i64* %ptr_c
  %r13 = load i64, i64* %ptr_c
  %r14 = getelementptr [2 x i8], [2 x i8]* @.str.360, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  %r16 = call i64 @_eq(i64 %r13, i64 %r15)
  store i64 1, i64* @.sc.359
  %r18 = icmp eq i64 %r16, 0
  br i1 %r18, label %L1083, label %L1084
L1083:
  %r19 = load i64, i64* %ptr_c
  %r20 = call i64 @codex(i64 %r19)
  %r21 = call i64 @_eq(i64 %r20, i64 10)
  %r22 = icmp ne i64 %r21, 0
  %r23 = zext i1 %r22 to i64
  store i64 %r23, i64* @.sc.359
  br label %L1084
L1084:
  %r17 = load i64, i64* @.sc.359
  %r24 = icmp ne i64 %r17, 0
  br i1 %r24, label %L1085, label %L1086
L1085:
  %r25 = load i64, i64* %ptr_cur
  %r26 = call i64 @mensura(i64 %r25)
  %r28 = icmp sgt i64 %r26, 0
  %r27 = zext i1 %r28 to i64
  %r29 = icmp ne i64 %r27, 0
  br i1 %r29, label %L1088, label %L1090
L1088:
  %r30 = load i64, i64* %ptr_cur
  %r31 = load i64, i64* %ptr_lines
  call i64 @_append_poly(i64 %r31, i64 %r30)
  %r32 = getelementptr [1 x i8], [1 x i8]* @.str.361, i64 0, i64 0
  %r33 = ptrtoint i8* %r32 to i64
  store i64 %r33, i64* %ptr_cur
  br label %L1090
L1090:
  br label %L1087
L1086:
  %r34 = load i64, i64* %ptr_cur
  %r35 = load i64, i64* %ptr_c
  %r36 = call i64 @_add(i64 %r34, i64 %r35)
  store i64 %r36, i64* %ptr_cur
  br label %L1087
L1087:
  %r37 = load i64, i64* %ptr_i
  %r38 = call i64 @_add(i64 %r37, i64 1)
  store i64 %r38, i64* %ptr_i
  br label %L1080
L1082:
  %r39 = load i64, i64* %ptr_cur
  %r40 = call i64 @mensura(i64 %r39)
  %r42 = icmp sgt i64 %r40, 0
  %r41 = zext i1 %r42 to i64
  %r43 = icmp ne i64 %r41, 0
  br i1 %r43, label %L1091, label %L1093
L1091:
  %r44 = load i64, i64* %ptr_cur
  %r45 = load i64, i64* %ptr_lines
  call i64 @_append_poly(i64 %r45, i64 %r44)
  br label %L1093
L1093:
  %r46 = call i64 @_list_new()
  store i64 %r46, i64* %ptr_regs
  store i64 0, i64* %ptr_i
  br label %L1094
L1094:
  %r47 = load i64, i64* %ptr_i
  %r49 = icmp slt i64 %r47, 26
  %r48 = zext i1 %r49 to i64
  %r50 = icmp ne i64 %r48, 0
  br i1 %r50, label %L1095, label %L1096
L1095:
  %r51 = load i64, i64* %ptr_regs
  call i64 @_append_poly(i64 %r51, i64 0)
  %r52 = load i64, i64* %ptr_i
  %r53 = call i64 @_add(i64 %r52, i64 1)
  store i64 %r53, i64* %ptr_i
  br label %L1094
L1096:
  store i64 0, i64* %ptr_pc
  store i64 10000, i64* %ptr_limit
  store i64 0, i64* %ptr_cycles
  br label %L1097
L1097:
  %r54 = load i64, i64* %ptr_pc
  %r55 = load i64, i64* %ptr_lines
  %r56 = call i64 @mensura(i64 %r55)
  %r58 = icmp slt i64 %r54, %r56
  %r57 = zext i1 %r58 to i64
  store i64 0, i64* @.sc.362
  %r60 = icmp ne i64 %r57, 0
  br i1 %r60, label %L1100, label %L1101
L1100:
  %r61 = load i64, i64* %ptr_cycles
  %r62 = load i64, i64* %ptr_limit
  %r64 = icmp slt i64 %r61, %r62
  %r63 = zext i1 %r64 to i64
  %r65 = icmp ne i64 %r63, 0
  %r66 = zext i1 %r65 to i64
  store i64 %r66, i64* @.sc.362
  br label %L1101
L1101:
  %r59 = load i64, i64* @.sc.362
  %r67 = icmp ne i64 %r59, 0
  br i1 %r67, label %L1098, label %L1099
L1098:
  %r68 = load i64, i64* %ptr_lines
  %r69 = load i64, i64* %ptr_pc
  %r70 = call i64 @_get(i64 %r68, i64 %r69)
  store i64 %r70, i64* %ptr_line
  %r71 = load i64, i64* %ptr_line
  %r72 = call i64 @mensura(i64 %r71)
  store i64 %r72, i64* %ptr_l_len
  %r73 = load i64, i64* %ptr_l_len
  %r75 = icmp sgt i64 %r73, 6
  %r74 = zext i1 %r75 to i64
  store i64 0, i64* @.sc.363
  %r77 = icmp ne i64 %r74, 0
  br i1 %r77, label %L1102, label %L1103
L1102:
  %r78 = load i64, i64* %ptr_line
  %r79 = call i64 @pars(i64 %r78, i64 0, i64 7)
  %r80 = getelementptr [8 x i8], [8 x i8]* @.str.364, i64 0, i64 0
  %r81 = ptrtoint i8* %r80 to i64
  %r82 = call i64 @_eq(i64 %r79, i64 %r81)
  %r83 = icmp ne i64 %r82, 0
  %r84 = zext i1 %r83 to i64
  store i64 %r84, i64* @.sc.363
  br label %L1103
L1103:
  %r76 = load i64, i64* @.sc.363
  %r85 = icmp ne i64 %r76, 0
  br i1 %r85, label %L1104, label %L1105
L1104:
  %r86 = load i64, i64* %ptr_node_idx
  %r87 = getelementptr [5 x i8], [5 x i8]* @.str.365, i64 0, i64 0
  %r88 = ptrtoint i8* %r87 to i64
  %r89 = load i64, i64* %ptr_line
  %r90 = load i64, i64* %ptr_l_len
  %r91 = sub i64 %r90, 7
  %r92 = call i64 @pars(i64 %r89, i64 7, i64 %r91)
  %r93 = call i64 @_add(i64 %r88, i64 %r92)
  %r94 = getelementptr [2 x i8], [2 x i8]* @.str.366, i64 0, i64 0
  %r95 = ptrtoint i8* %r94 to i64
  %r96 = call i64 @_add(i64 %r93, i64 %r95)
  %r97 = call i64 @send_msg(i64 %r86, i64 %r96)
  br label %L1106
L1105:
  %r98 = load i64, i64* %ptr_l_len
  %r100 = icmp sge i64 %r98, 6
  %r99 = zext i1 %r100 to i64
  store i64 0, i64* @.sc.367
  %r102 = icmp ne i64 %r99, 0
  br i1 %r102, label %L1107, label %L1108
L1107:
  %r103 = load i64, i64* %ptr_line
  %r104 = call i64 @pars(i64 %r103, i64 0, i64 6)
  %r105 = getelementptr [7 x i8], [7 x i8]* @.str.368, i64 0, i64 0
  %r106 = ptrtoint i8* %r105 to i64
  %r107 = call i64 @_eq(i64 %r104, i64 %r106)
  %r108 = icmp ne i64 %r107, 0
  %r109 = zext i1 %r108 to i64
  store i64 %r109, i64* @.sc.367
  br label %L1108
L1108:
  %r101 = load i64, i64* @.sc.367
  %r110 = icmp ne i64 %r101, 0
  br i1 %r110, label %L1109, label %L1110
L1109:
  %r111 = load i64, i64* %ptr_line
  %r112 = call i64 @pars(i64 %r111, i64 6, i64 1)
  %r113 = call i64 @codex(i64 %r112)
  %r114 = sub i64 %r113, 97
  store i64 %r114, i64* %ptr_r_idx
  %r115 = load i64, i64* %ptr_r_idx
  %r117 = icmp sge i64 %r115, 0
  %r116 = zext i1 %r117 to i64
  store i64 0, i64* @.sc.369
  %r119 = icmp ne i64 %r116, 0
  br i1 %r119, label %L1112, label %L1113
L1112:
  %r120 = load i64, i64* %ptr_r_idx
  %r122 = icmp slt i64 %r120, 26
  %r121 = zext i1 %r122 to i64
  %r123 = icmp ne i64 %r121, 0
  %r124 = zext i1 %r123 to i64
  store i64 %r124, i64* @.sc.369
  br label %L1113
L1113:
  %r118 = load i64, i64* @.sc.369
  %r125 = icmp ne i64 %r118, 0
  br i1 %r125, label %L1114, label %L1116
L1114:
  %r126 = load i64, i64* %ptr_node_idx
  %r127 = getelementptr [5 x i8], [5 x i8]* @.str.370, i64 0, i64 0
  %r128 = ptrtoint i8* %r127 to i64
  %r129 = load i64, i64* %ptr_regs
  %r130 = load i64, i64* %ptr_r_idx
  %r131 = call i64 @_get(i64 %r129, i64 %r130)
  %r132 = call i64 @int_to_str(i64 %r131)
  %r133 = call i64 @_add(i64 %r128, i64 %r132)
  %r134 = getelementptr [2 x i8], [2 x i8]* @.str.371, i64 0, i64 0
  %r135 = ptrtoint i8* %r134 to i64
  %r136 = call i64 @_add(i64 %r133, i64 %r135)
  %r137 = call i64 @send_msg(i64 %r126, i64 %r136)
  br label %L1116
L1116:
  br label %L1111
L1110:
  %r138 = load i64, i64* %ptr_l_len
  %r140 = icmp sge i64 %r138, 6
  %r139 = zext i1 %r140 to i64
  store i64 0, i64* @.sc.372
  %r142 = icmp ne i64 %r139, 0
  br i1 %r142, label %L1117, label %L1118
L1117:
  %r143 = load i64, i64* %ptr_line
  %r144 = call i64 @pars(i64 %r143, i64 0, i64 4)
  %r145 = getelementptr [5 x i8], [5 x i8]* @.str.373, i64 0, i64 0
  %r146 = ptrtoint i8* %r145 to i64
  %r147 = call i64 @_eq(i64 %r144, i64 %r146)
  %r148 = icmp ne i64 %r147, 0
  %r149 = zext i1 %r148 to i64
  store i64 %r149, i64* @.sc.372
  br label %L1118
L1118:
  %r141 = load i64, i64* @.sc.372
  %r150 = icmp ne i64 %r141, 0
  br i1 %r150, label %L1119, label %L1120
L1119:
  %r151 = load i64, i64* %ptr_line
  %r152 = call i64 @pars(i64 %r151, i64 4, i64 1)
  %r153 = call i64 @codex(i64 %r152)
  %r154 = sub i64 %r153, 97
  store i64 %r154, i64* %ptr_r_idx
  %r155 = load i64, i64* %ptr_r_idx
  %r157 = icmp sge i64 %r155, 0
  %r156 = zext i1 %r157 to i64
  store i64 0, i64* @.sc.374
  %r159 = icmp ne i64 %r156, 0
  br i1 %r159, label %L1122, label %L1123
L1122:
  %r160 = load i64, i64* %ptr_r_idx
  %r162 = icmp slt i64 %r160, 26
  %r161 = zext i1 %r162 to i64
  %r163 = icmp ne i64 %r161, 0
  %r164 = zext i1 %r163 to i64
  store i64 %r164, i64* @.sc.374
  br label %L1123
L1123:
  %r158 = load i64, i64* @.sc.374
  %r165 = icmp ne i64 %r158, 0
  br i1 %r165, label %L1124, label %L1126
L1124:
  %r166 = load i64, i64* %ptr_line
  %r167 = load i64, i64* %ptr_l_len
  %r168 = sub i64 %r167, 6
  %r169 = call i64 @pars(i64 %r166, i64 6, i64 %r168)
  %r170 = call i64 @str_to_int(i64 %r169)
  %r171 = load i64, i64* %ptr_r_idx
  %r172 = load i64, i64* %ptr_regs
  call i64 @_set(i64 %r172, i64 %r171, i64 %r170)
  br label %L1126
L1126:
  br label %L1121
L1120:
  %r173 = load i64, i64* %ptr_l_len
  %r175 = icmp sge i64 %r173, 6
  %r174 = zext i1 %r175 to i64
  store i64 0, i64* @.sc.375
  %r177 = icmp ne i64 %r174, 0
  br i1 %r177, label %L1127, label %L1128
L1127:
  %r178 = load i64, i64* %ptr_line
  %r179 = call i64 @pars(i64 %r178, i64 0, i64 4)
  %r180 = getelementptr [5 x i8], [5 x i8]* @.str.376, i64 0, i64 0
  %r181 = ptrtoint i8* %r180 to i64
  %r182 = call i64 @_eq(i64 %r179, i64 %r181)
  %r183 = icmp ne i64 %r182, 0
  %r184 = zext i1 %r183 to i64
  store i64 %r184, i64* @.sc.375
  br label %L1128
L1128:
  %r176 = load i64, i64* @.sc.375
  %r185 = icmp ne i64 %r176, 0
  br i1 %r185, label %L1129, label %L1130
L1129:
  %r186 = load i64, i64* %ptr_line
  %r187 = call i64 @pars(i64 %r186, i64 4, i64 1)
  %r188 = call i64 @codex(i64 %r187)
  %r189 = sub i64 %r188, 97
  store i64 %r189, i64* %ptr_r_idx
  %r190 = load i64, i64* %ptr_r_idx
  %r192 = icmp sge i64 %r190, 0
  %r191 = zext i1 %r192 to i64
  store i64 0, i64* @.sc.377
  %r194 = icmp ne i64 %r191, 0
  br i1 %r194, label %L1132, label %L1133
L1132:
  %r195 = load i64, i64* %ptr_r_idx
  %r197 = icmp slt i64 %r195, 26
  %r196 = zext i1 %r197 to i64
  %r198 = icmp ne i64 %r196, 0
  %r199 = zext i1 %r198 to i64
  store i64 %r199, i64* @.sc.377
  br label %L1133
L1133:
  %r193 = load i64, i64* @.sc.377
  %r200 = icmp ne i64 %r193, 0
  br i1 %r200, label %L1134, label %L1136
L1134:
  %r201 = load i64, i64* %ptr_regs
  %r202 = load i64, i64* %ptr_r_idx
  %r203 = call i64 @_get(i64 %r201, i64 %r202)
  %r204 = load i64, i64* %ptr_line
  %r205 = load i64, i64* %ptr_l_len
  %r206 = sub i64 %r205, 6
  %r207 = call i64 @pars(i64 %r204, i64 6, i64 %r206)
  %r208 = call i64 @str_to_int(i64 %r207)
  %r209 = call i64 @_add(i64 %r203, i64 %r208)
  %r210 = load i64, i64* %ptr_r_idx
  %r211 = load i64, i64* %ptr_regs
  call i64 @_set(i64 %r211, i64 %r210, i64 %r209)
  br label %L1136
L1136:
  br label %L1131
L1130:
  %r212 = load i64, i64* %ptr_l_len
  %r214 = icmp sge i64 %r212, 6
  %r213 = zext i1 %r214 to i64
  store i64 0, i64* @.sc.378
  %r216 = icmp ne i64 %r213, 0
  br i1 %r216, label %L1137, label %L1138
L1137:
  %r217 = load i64, i64* %ptr_line
  %r218 = call i64 @pars(i64 %r217, i64 0, i64 4)
  %r219 = getelementptr [5 x i8], [5 x i8]* @.str.379, i64 0, i64 0
  %r220 = ptrtoint i8* %r219 to i64
  %r221 = call i64 @_eq(i64 %r218, i64 %r220)
  %r222 = icmp ne i64 %r221, 0
  %r223 = zext i1 %r222 to i64
  store i64 %r223, i64* @.sc.378
  br label %L1138
L1138:
  %r215 = load i64, i64* @.sc.378
  %r224 = icmp ne i64 %r215, 0
  br i1 %r224, label %L1139, label %L1140
L1139:
  %r225 = load i64, i64* %ptr_line
  %r226 = call i64 @pars(i64 %r225, i64 4, i64 1)
  %r227 = call i64 @codex(i64 %r226)
  %r228 = sub i64 %r227, 97
  store i64 %r228, i64* %ptr_r_idx
  %r229 = load i64, i64* %ptr_r_idx
  %r231 = icmp sge i64 %r229, 0
  %r230 = zext i1 %r231 to i64
  store i64 0, i64* @.sc.380
  %r233 = icmp ne i64 %r230, 0
  br i1 %r233, label %L1142, label %L1143
L1142:
  %r234 = load i64, i64* %ptr_r_idx
  %r236 = icmp slt i64 %r234, 26
  %r235 = zext i1 %r236 to i64
  %r237 = icmp ne i64 %r235, 0
  %r238 = zext i1 %r237 to i64
  store i64 %r238, i64* @.sc.380
  br label %L1143
L1143:
  %r232 = load i64, i64* @.sc.380
  %r239 = icmp ne i64 %r232, 0
  br i1 %r239, label %L1144, label %L1146
L1144:
  %r240 = load i64, i64* %ptr_regs
  %r241 = load i64, i64* %ptr_r_idx
  %r242 = call i64 @_get(i64 %r240, i64 %r241)
  %r243 = load i64, i64* %ptr_line
  %r244 = load i64, i64* %ptr_l_len
  %r245 = sub i64 %r244, 6
  %r246 = call i64 @pars(i64 %r243, i64 6, i64 %r245)
  %r247 = call i64 @str_to_int(i64 %r246)
  %r248 = sub i64 %r242, %r247
  %r249 = load i64, i64* %ptr_r_idx
  %r250 = load i64, i64* %ptr_regs
  call i64 @_set(i64 %r250, i64 %r249, i64 %r248)
  br label %L1146
L1146:
  br label %L1141
L1140:
  %r251 = load i64, i64* %ptr_l_len
  %r253 = icmp sge i64 %r251, 5
  %r252 = zext i1 %r253 to i64
  store i64 0, i64* @.sc.381
  %r255 = icmp ne i64 %r252, 0
  br i1 %r255, label %L1147, label %L1148
L1147:
  %r256 = load i64, i64* %ptr_line
  %r257 = call i64 @pars(i64 %r256, i64 0, i64 5)
  %r258 = getelementptr [6 x i8], [6 x i8]* @.str.382, i64 0, i64 0
  %r259 = ptrtoint i8* %r258 to i64
  %r260 = call i64 @_eq(i64 %r257, i64 %r259)
  %r261 = icmp ne i64 %r260, 0
  %r262 = zext i1 %r261 to i64
  store i64 %r262, i64* @.sc.381
  br label %L1148
L1148:
  %r254 = load i64, i64* @.sc.381
  %r263 = icmp ne i64 %r254, 0
  br i1 %r263, label %L1149, label %L1150
L1149:
  %r264 = load i64, i64* %ptr_line
  %r265 = load i64, i64* %ptr_l_len
  %r266 = sub i64 %r265, 5
  %r267 = call i64 @pars(i64 %r264, i64 5, i64 %r266)
  %r268 = call i64 @str_to_int(i64 %r267)
  %r269 = sub i64 %r268, 1
  store i64 %r269, i64* %ptr_pc
  br label %L1151
L1150:
  %r270 = load i64, i64* %ptr_l_len
  %r272 = icmp sge i64 %r270, 8
  %r271 = zext i1 %r272 to i64
  store i64 0, i64* @.sc.383
  %r274 = icmp ne i64 %r271, 0
  br i1 %r274, label %L1152, label %L1153
L1152:
  %r275 = load i64, i64* %ptr_line
  %r276 = call i64 @pars(i64 %r275, i64 0, i64 4)
  %r277 = getelementptr [5 x i8], [5 x i8]* @.str.384, i64 0, i64 0
  %r278 = ptrtoint i8* %r277 to i64
  %r279 = call i64 @_eq(i64 %r276, i64 %r278)
  %r280 = icmp ne i64 %r279, 0
  %r281 = zext i1 %r280 to i64
  store i64 %r281, i64* @.sc.383
  br label %L1153
L1153:
  %r273 = load i64, i64* @.sc.383
  %r282 = icmp ne i64 %r273, 0
  br i1 %r282, label %L1154, label %L1156
L1154:
  %r283 = load i64, i64* %ptr_line
  %r284 = call i64 @pars(i64 %r283, i64 4, i64 1)
  %r285 = call i64 @codex(i64 %r284)
  %r286 = sub i64 %r285, 97
  store i64 %r286, i64* %ptr_r_idx
  %r287 = load i64, i64* %ptr_line
  %r288 = load i64, i64* %ptr_l_len
  %r289 = sub i64 %r288, 6
  %r290 = call i64 @pars(i64 %r287, i64 6, i64 %r289)
  store i64 %r290, i64* %ptr_rest
  store i64 0, i64* %ptr_sp
  store i64 0, i64* %ptr_j
  br label %L1157
L1157:
  %r291 = load i64, i64* %ptr_j
  %r292 = load i64, i64* %ptr_rest
  %r293 = call i64 @mensura(i64 %r292)
  %r295 = icmp slt i64 %r291, %r293
  %r294 = zext i1 %r295 to i64
  %r296 = icmp ne i64 %r294, 0
  br i1 %r296, label %L1158, label %L1159
L1158:
  %r297 = load i64, i64* %ptr_rest
  %r298 = load i64, i64* %ptr_j
  %r299 = call i64 @pars(i64 %r297, i64 %r298, i64 1)
  %r300 = getelementptr [2 x i8], [2 x i8]* @.str.385, i64 0, i64 0
  %r301 = ptrtoint i8* %r300 to i64
  %r302 = call i64 @_eq(i64 %r299, i64 %r301)
  %r303 = icmp ne i64 %r302, 0
  br i1 %r303, label %L1160, label %L1162
L1160:
  %r304 = load i64, i64* %ptr_j
  store i64 %r304, i64* %ptr_sp
  %r305 = load i64, i64* %ptr_rest
  %r306 = call i64 @mensura(i64 %r305)
  store i64 %r306, i64* %ptr_j
  br label %L1162
L1162:
  %r307 = load i64, i64* %ptr_j
  %r308 = call i64 @_add(i64 %r307, i64 1)
  store i64 %r308, i64* %ptr_j
  br label %L1157
L1159:
  %r309 = load i64, i64* %ptr_sp
  %r311 = icmp sgt i64 %r309, 0
  %r310 = zext i1 %r311 to i64
  store i64 0, i64* @.sc.387
  %r313 = icmp ne i64 %r310, 0
  br i1 %r313, label %L1163, label %L1164
L1163:
  %r314 = load i64, i64* %ptr_r_idx
  %r316 = icmp sge i64 %r314, 0
  %r315 = zext i1 %r316 to i64
  %r317 = icmp ne i64 %r315, 0
  %r318 = zext i1 %r317 to i64
  store i64 %r318, i64* @.sc.387
  br label %L1164
L1164:
  %r312 = load i64, i64* @.sc.387
  store i64 0, i64* @.sc.386
  %r320 = icmp ne i64 %r312, 0
  br i1 %r320, label %L1165, label %L1166
L1165:
  %r321 = load i64, i64* %ptr_r_idx
  %r323 = icmp slt i64 %r321, 26
  %r322 = zext i1 %r323 to i64
  %r324 = icmp ne i64 %r322, 0
  %r325 = zext i1 %r324 to i64
  store i64 %r325, i64* @.sc.386
  br label %L1166
L1166:
  %r319 = load i64, i64* @.sc.386
  %r326 = icmp ne i64 %r319, 0
  br i1 %r326, label %L1167, label %L1169
L1167:
  %r327 = load i64, i64* %ptr_rest
  %r328 = load i64, i64* %ptr_sp
  %r329 = call i64 @pars(i64 %r327, i64 0, i64 %r328)
  %r330 = call i64 @str_to_int(i64 %r329)
  store i64 %r330, i64* %ptr_cmp_v
  %r331 = load i64, i64* %ptr_rest
  %r332 = load i64, i64* %ptr_sp
  %r333 = call i64 @_add(i64 %r332, i64 1)
  %r334 = load i64, i64* %ptr_rest
  %r335 = call i64 @mensura(i64 %r334)
  %r336 = load i64, i64* %ptr_sp
  %r337 = sub i64 %r335, %r336
  %r338 = sub i64 %r337, 1
  %r339 = call i64 @pars(i64 %r331, i64 %r333, i64 %r338)
  %r340 = call i64 @str_to_int(i64 %r339)
  store i64 %r340, i64* %ptr_targ
  %r341 = load i64, i64* %ptr_regs
  %r342 = load i64, i64* %ptr_r_idx
  %r343 = call i64 @_get(i64 %r341, i64 %r342)
  %r344 = load i64, i64* %ptr_cmp_v
  %r346 = icmp slt i64 %r343, %r344
  %r345 = zext i1 %r346 to i64
  %r347 = icmp ne i64 %r345, 0
  br i1 %r347, label %L1170, label %L1172
L1170:
  %r348 = load i64, i64* %ptr_targ
  %r349 = sub i64 %r348, 1
  store i64 %r349, i64* %ptr_pc
  br label %L1172
L1172:
  br label %L1169
L1169:
  br label %L1156
L1156:
  br label %L1151
L1151:
  br label %L1141
L1141:
  br label %L1131
L1131:
  br label %L1121
L1121:
  br label %L1111
L1111:
  br label %L1106
L1106:
  %r350 = load i64, i64* %ptr_pc
  %r351 = call i64 @_add(i64 %r350, i64 1)
  store i64 %r351, i64* %ptr_pc
  %r352 = load i64, i64* %ptr_cycles
  %r353 = call i64 @_add(i64 %r352, i64 1)
  store i64 %r353, i64* %ptr_cycles
  br label %L1097
L1099:
  %r354 = load i64, i64* %ptr_node_idx
  %r355 = getelementptr [27 x i8], [27 x i8]* @.str.388, i64 0, i64 0
  %r356 = ptrtoint i8* %r355 to i64
  %r357 = load i64, i64* %ptr_cycles
  %r358 = call i64 @int_to_str(i64 %r357)
  %r359 = call i64 @_add(i64 %r356, i64 %r358)
  %r360 = getelementptr [2 x i8], [2 x i8]* @.str.389, i64 0, i64 0
  %r361 = ptrtoint i8* %r360 to i64
  %r362 = call i64 @_add(i64 %r359, i64 %r361)
  %r363 = call i64 @send_msg(i64 %r354, i64 %r362)
  ret i64 0
}
define i64 @read_string(i64 %arg_addr) {
  %ptr_addr = alloca i64
  store i64 %arg_addr, i64* %ptr_addr
  %ptr_out = alloca i64
  %ptr_i = alloca i64
  %ptr_b = alloca i64
  %r1 = getelementptr [1 x i8], [1 x i8]* @.str.390, i64 0, i64 0
  %r2 = ptrtoint i8* %r1 to i64
  store i64 %r2, i64* %ptr_out
  %r3 = load i64, i64* %ptr_addr
  %r4 = call i64 @_eq(i64 %r3, i64 0)
  %r5 = icmp ne i64 %r4, 0
  br i1 %r5, label %L1173, label %L1175
L1173:
  %r6 = load i64, i64* %ptr_out
  ret i64 %r6
  br label %L1175
L1175:
  store i64 0, i64* %ptr_i
  br label %L1176
L1176:
  %r7 = icmp ne i64 1, 0
  br i1 %r7, label %L1177, label %L1178
L1177:
  %r8 = load i64, i64* %ptr_addr
  %r9 = load i64, i64* %ptr_i
  %r10 = add i64 %r8, %r9
  %r11 = inttoptr i64 %r10 to ptr
  %r12 = load volatile i8, ptr %r11
  %r13 = zext i8 %r12 to i64
  store i64 %r13, i64* %ptr_b
  %r14 = load i64, i64* %ptr_b
  %r15 = call i64 @_eq(i64 %r14, i64 0)
  %r16 = icmp ne i64 %r15, 0
  br i1 %r16, label %L1179, label %L1181
L1179:
  br label %L1178
L1181:
  %r17 = load i64, i64* %ptr_out
  %r18 = load i64, i64* %ptr_b
  %r19 = call i64 @signum_ex(i64 %r18)
  %r20 = call i64 @_add(i64 %r17, i64 %r19)
  store i64 %r20, i64* %ptr_out
  %r21 = load i64, i64* %ptr_i
  %r22 = call i64 @_add(i64 %r21, i64 1)
  store i64 %r22, i64* %ptr_i
  br label %L1176
L1178:
  %r23 = load i64, i64* %ptr_out
  ret i64 %r23
  ret i64 0
}
define i64 @file_exists(i64 %arg_target_name) {
  %ptr_target_name = alloca i64
  store i64 %arg_target_name, i64* %ptr_target_name
  %ptr_i = alloca i64
  store i64 0, i64* %ptr_i
  br label %L1182
L1182:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @vfs_name
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp slt i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L1183, label %L1184
L1183:
  %r7 = load i64, i64* @vfs_name
  %r8 = load i64, i64* %ptr_i
  %r9 = call i64 @_get(i64 %r7, i64 %r8)
  %r10 = load i64, i64* %ptr_target_name
  %r11 = call i64 @_eq(i64 %r9, i64 %r10)
  %r12 = icmp ne i64 %r11, 0
  br i1 %r12, label %L1185, label %L1187
L1185:
  ret i64 1
  br label %L1187
L1187:
  %r13 = load i64, i64* %ptr_i
  %r14 = call i64 @_add(i64 %r13, i64 1)
  store i64 %r14, i64* %ptr_i
  br label %L1182
L1184:
  ret i64 0
  ret i64 0
}
define i64 @write_file(i64 %arg_target_name, i64 %arg_content) {
  %ptr_target_name = alloca i64
  store i64 %arg_target_name, i64* %ptr_target_name
  %ptr_content = alloca i64
  store i64 %arg_content, i64* %ptr_content
  %ptr_len = alloca i64
  %ptr_alloc_len = alloca i64
  %ptr_new_addr = alloca i64
  %ptr_j = alloca i64
  %ptr_c = alloca i64
  %ptr_found = alloca i64
  %ptr_i = alloca i64
  %r1 = load i64, i64* %ptr_content
  %r2 = call i64 @mensura(i64 %r1)
  store i64 %r2, i64* %ptr_len
  %r3 = load i64, i64* %ptr_len
  store i64 %r3, i64* %ptr_alloc_len
  %r4 = load i64, i64* %ptr_alloc_len
  %r5 = call i64 @_eq(i64 %r4, i64 0)
  %r6 = icmp ne i64 %r5, 0
  br i1 %r6, label %L1188, label %L1190
L1188:
  store i64 1, i64* %ptr_alloc_len
  br label %L1190
L1190:
  %r7 = load i64, i64* %ptr_alloc_len
  %r8 = call i64 @malloc(i64 %r7)
  store i64 %r8, i64* %ptr_new_addr
  store i64 0, i64* %ptr_j
  br label %L1191
L1191:
  %r9 = load i64, i64* %ptr_j
  %r10 = load i64, i64* %ptr_len
  %r12 = icmp slt i64 %r9, %r10
  %r11 = zext i1 %r12 to i64
  %r13 = icmp ne i64 %r11, 0
  br i1 %r13, label %L1192, label %L1193
L1192:
  %r14 = load i64, i64* %ptr_content
  %r15 = load i64, i64* %ptr_j
  %r16 = call i64 @pars(i64 %r14, i64 %r15, i64 1)
  store i64 %r16, i64* %ptr_c
  %r17 = load i64, i64* %ptr_new_addr
  %r18 = load i64, i64* %ptr_j
  %r19 = add i64 %r17, %r18
  %r20 = load i64, i64* %ptr_c
  %r21 = call i64 @codex(i64 %r20)
  %r22 = inttoptr i64 %r19 to ptr
  %r23 = trunc i64 %r21 to i8
  store volatile i8 %r23, ptr %r22
  %r24 = load i64, i64* %ptr_j
  %r25 = call i64 @_add(i64 %r24, i64 1)
  store i64 %r25, i64* %ptr_j
  br label %L1191
L1193:
  store i64 0, i64* %ptr_found
  store i64 0, i64* %ptr_i
  br label %L1194
L1194:
  %r26 = load i64, i64* %ptr_i
  %r27 = load i64, i64* @vfs_name
  %r28 = call i64 @mensura(i64 %r27)
  %r30 = icmp slt i64 %r26, %r28
  %r29 = zext i1 %r30 to i64
  %r31 = icmp ne i64 %r29, 0
  br i1 %r31, label %L1195, label %L1196
L1195:
  %r32 = load i64, i64* @vfs_name
  %r33 = load i64, i64* %ptr_i
  %r34 = call i64 @_get(i64 %r32, i64 %r33)
  %r35 = load i64, i64* %ptr_target_name
  %r36 = call i64 @_eq(i64 %r34, i64 %r35)
  %r37 = icmp ne i64 %r36, 0
  br i1 %r37, label %L1197, label %L1199
L1197:
  %r38 = load i64, i64* %ptr_new_addr
  %r39 = load i64, i64* %ptr_i
  %r40 = load i64, i64* @vfs_start
  call i64 @_set(i64 %r40, i64 %r39, i64 %r38)
  %r41 = load i64, i64* %ptr_len
  %r42 = load i64, i64* %ptr_i
  %r43 = load i64, i64* @vfs_size
  call i64 @_set(i64 %r43, i64 %r42, i64 %r41)
  store i64 1, i64* %ptr_found
  br label %L1199
L1199:
  %r44 = load i64, i64* %ptr_i
  %r45 = call i64 @_add(i64 %r44, i64 1)
  store i64 %r45, i64* %ptr_i
  br label %L1194
L1196:
  %r46 = load i64, i64* %ptr_found
  %r47 = call i64 @_eq(i64 %r46, i64 0)
  %r48 = icmp ne i64 %r47, 0
  br i1 %r48, label %L1200, label %L1202
L1200:
  %r49 = load i64, i64* %ptr_target_name
  %r50 = load i64, i64* @vfs_name
  call i64 @_append_poly(i64 %r50, i64 %r49)
  %r51 = load i64, i64* %ptr_new_addr
  %r52 = load i64, i64* @vfs_start
  call i64 @_append_poly(i64 %r52, i64 %r51)
  %r53 = load i64, i64* %ptr_len
  %r54 = load i64, i64* @vfs_size
  call i64 @_append_poly(i64 %r54, i64 %r53)
  br label %L1202
L1202:
  ret i64 0
}
define i64 @init_vfs() {
  %ptr_count = alloca i64
  %ptr_mods_addr = alloca i64
  %ptr_i = alloca i64
  %ptr_mod_ptr = alloca i64
  %ptr_m_start = alloca i64
  %ptr_m_end = alloca i64
  %ptr_str_addr = alloca i64
  %ptr_m_name = alloca i64
  %r1 = call i64 @read_32(i64 20496)
  store i64 %r1, i64* %ptr_count
  %r2 = call i64 @read_32(i64 20500)
  store i64 %r2, i64* %ptr_mods_addr
  store i64 0, i64* %ptr_i
  br label %L1203
L1203:
  %r3 = load i64, i64* %ptr_i
  %r4 = load i64, i64* %ptr_count
  %r6 = icmp slt i64 %r3, %r4
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L1204, label %L1205
L1204:
  %r8 = load i64, i64* %ptr_mods_addr
  %r9 = load i64, i64* %ptr_i
  %r10 = mul i64 %r9, 16
  %r11 = add i64 %r8, %r10
  store i64 %r11, i64* %ptr_mod_ptr
  %r12 = load i64, i64* %ptr_mod_ptr
  %r13 = call i64 @read_32(i64 %r12)
  store i64 %r13, i64* %ptr_m_start
  %r14 = load i64, i64* %ptr_mod_ptr
  %r15 = add i64 %r14, 4
  %r16 = call i64 @read_32(i64 %r15)
  store i64 %r16, i64* %ptr_m_end
  %r17 = load i64, i64* %ptr_mod_ptr
  %r18 = add i64 %r17, 8
  %r19 = call i64 @read_32(i64 %r18)
  store i64 %r19, i64* %ptr_str_addr
  %r20 = load i64, i64* %ptr_str_addr
  %r21 = call i64 @read_string(i64 %r20)
  store i64 %r21, i64* %ptr_m_name
  %r22 = load i64, i64* %ptr_m_name
  %r23 = call i64 @mensura(i64 %r22)
  %r24 = call i64 @_eq(i64 %r23, i64 0)
  %r25 = icmp ne i64 %r24, 0
  br i1 %r25, label %L1206, label %L1208
L1206:
  %r26 = load i64, i64* %ptr_i
  %r27 = call i64 @_eq(i64 %r26, i64 0)
  %r28 = icmp ne i64 %r27, 0
  br i1 %r28, label %L1209, label %L1210
L1209:
  %r29 = getelementptr [8 x i8], [8 x i8]* @.str.391, i64 0, i64 0
  %r30 = ptrtoint i8* %r29 to i64
  store i64 %r30, i64* %ptr_m_name
  br label %L1211
L1210:
  %r31 = load i64, i64* %ptr_i
  %r32 = call i64 @_eq(i64 %r31, i64 1)
  %r33 = icmp ne i64 %r32, 0
  br i1 %r33, label %L1212, label %L1213
L1212:
  %r34 = getelementptr [13 x i8], [13 x i8]* @.str.392, i64 0, i64 0
  %r35 = ptrtoint i8* %r34 to i64
  store i64 %r35, i64* %ptr_m_name
  br label %L1214
L1213:
  %r36 = load i64, i64* %ptr_i
  %r37 = call i64 @_eq(i64 %r36, i64 2)
  %r38 = icmp ne i64 %r37, 0
  br i1 %r38, label %L1215, label %L1216
L1215:
  %r39 = getelementptr [11 x i8], [11 x i8]* @.str.393, i64 0, i64 0
  %r40 = ptrtoint i8* %r39 to i64
  store i64 %r40, i64* %ptr_m_name
  br label %L1217
L1216:
  %r41 = getelementptr [5 x i8], [5 x i8]* @.str.394, i64 0, i64 0
  %r42 = ptrtoint i8* %r41 to i64
  %r43 = load i64, i64* %ptr_i
  %r44 = call i64 @int_to_str(i64 %r43)
  %r45 = call i64 @_add(i64 %r42, i64 %r44)
  %r46 = getelementptr [5 x i8], [5 x i8]* @.str.395, i64 0, i64 0
  %r47 = ptrtoint i8* %r46 to i64
  %r48 = call i64 @_add(i64 %r45, i64 %r47)
  store i64 %r48, i64* %ptr_m_name
  br label %L1217
L1217:
  br label %L1214
L1214:
  br label %L1211
L1211:
  br label %L1208
L1208:
  %r49 = load i64, i64* %ptr_m_name
  %r50 = load i64, i64* @vfs_name
  call i64 @_append_poly(i64 %r50, i64 %r49)
  %r51 = load i64, i64* %ptr_m_start
  %r52 = load i64, i64* @vfs_start
  call i64 @_append_poly(i64 %r52, i64 %r51)
  %r53 = load i64, i64* %ptr_m_end
  %r54 = load i64, i64* %ptr_m_start
  %r55 = sub i64 %r53, %r54
  %r56 = load i64, i64* @vfs_size
  call i64 @_append_poly(i64 %r56, i64 %r55)
  %r57 = load i64, i64* %ptr_i
  %r58 = call i64 @_add(i64 %r57, i64 1)
  store i64 %r58, i64* %ptr_i
  br label %L1203
L1205:
  ret i64 0
}
define i64 @read_file(i64 %arg_target_name) {
  %ptr_target_name = alloca i64
  store i64 %arg_target_name, i64* %ptr_target_name
  %ptr_i = alloca i64
  %ptr_addr = alloca i64
  %ptr_size = alloca i64
  %ptr_out = alloca i64
  %ptr_j = alloca i64
  store i64 0, i64* %ptr_i
  br label %L1218
L1218:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @vfs_name
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp slt i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L1219, label %L1220
L1219:
  %r7 = load i64, i64* @vfs_name
  %r8 = load i64, i64* %ptr_i
  %r9 = call i64 @_get(i64 %r7, i64 %r8)
  %r10 = load i64, i64* %ptr_target_name
  %r11 = call i64 @_eq(i64 %r9, i64 %r10)
  %r12 = icmp ne i64 %r11, 0
  br i1 %r12, label %L1221, label %L1223
L1221:
  %r13 = load i64, i64* @vfs_start
  %r14 = load i64, i64* %ptr_i
  %r15 = call i64 @_get(i64 %r13, i64 %r14)
  store i64 %r15, i64* %ptr_addr
  %r16 = load i64, i64* @vfs_size
  %r17 = load i64, i64* %ptr_i
  %r18 = call i64 @_get(i64 %r16, i64 %r17)
  store i64 %r18, i64* %ptr_size
  %r19 = getelementptr [1 x i8], [1 x i8]* @.str.396, i64 0, i64 0
  %r20 = ptrtoint i8* %r19 to i64
  store i64 %r20, i64* %ptr_out
  store i64 0, i64* %ptr_j
  br label %L1224
L1224:
  %r21 = load i64, i64* %ptr_j
  %r22 = load i64, i64* %ptr_size
  %r24 = icmp slt i64 %r21, %r22
  %r23 = zext i1 %r24 to i64
  %r25 = icmp ne i64 %r23, 0
  br i1 %r25, label %L1225, label %L1226
L1225:
  %r26 = load i64, i64* %ptr_out
  %r27 = load i64, i64* %ptr_addr
  %r28 = load i64, i64* %ptr_j
  %r29 = add i64 %r27, %r28
  %r30 = inttoptr i64 %r29 to ptr
  %r31 = load volatile i8, ptr %r30
  %r32 = zext i8 %r31 to i64
  %r33 = call i64 @signum_ex(i64 %r32)
  %r34 = call i64 @_add(i64 %r26, i64 %r33)
  store i64 %r34, i64* %ptr_out
  %r35 = load i64, i64* %ptr_j
  %r36 = call i64 @_add(i64 %r35, i64 1)
  store i64 %r36, i64* %ptr_j
  br label %L1224
L1226:
  %r37 = load i64, i64* %ptr_out
  ret i64 %r37
  br label %L1223
L1223:
  %r38 = load i64, i64* %ptr_i
  %r39 = call i64 @_add(i64 %r38, i64 1)
  store i64 %r39, i64* %ptr_i
  br label %L1218
L1220:
  %r40 = getelementptr [24 x i8], [24 x i8]* @.str.397, i64 0, i64 0
  %r41 = ptrtoint i8* %r40 to i64
  %r42 = load i64, i64* %ptr_target_name
  %r43 = call i64 @_add(i64 %r41, i64 %r42)
  ret i64 %r43
  ret i64 0
}
define i64 @remove_wire(i64 %arg_w_idx) {
  %ptr_w_idx = alloca i64
  store i64 %arg_w_idx, i64* %ptr_w_idx
  %ptr_new_f = alloca i64
  %ptr_new_t = alloca i64
  %ptr_i = alloca i64
  %r1 = call i64 @_list_new()
  store i64 %r1, i64* %ptr_new_f
  %r2 = call i64 @_list_new()
  store i64 %r2, i64* %ptr_new_t
  store i64 0, i64* %ptr_i
  br label %L1227
L1227:
  %r3 = load i64, i64* %ptr_i
  %r4 = load i64, i64* @wire_from
  %r5 = call i64 @mensura(i64 %r4)
  %r7 = icmp slt i64 %r3, %r5
  %r6 = zext i1 %r7 to i64
  %r8 = icmp ne i64 %r6, 0
  br i1 %r8, label %L1228, label %L1229
L1228:
  %r9 = load i64, i64* %ptr_i
  %r10 = load i64, i64* %ptr_w_idx
  %r12 = call i64 @_eq(i64 %r9, i64 %r10)
  %r11 = xor i64 %r12, 1
  %r13 = icmp ne i64 %r11, 0
  br i1 %r13, label %L1230, label %L1232
L1230:
  %r14 = load i64, i64* @wire_from
  %r15 = load i64, i64* %ptr_i
  %r16 = call i64 @_get(i64 %r14, i64 %r15)
  %r17 = load i64, i64* %ptr_new_f
  call i64 @_append_poly(i64 %r17, i64 %r16)
  %r18 = load i64, i64* @wire_to
  %r19 = load i64, i64* %ptr_i
  %r20 = call i64 @_get(i64 %r18, i64 %r19)
  %r21 = load i64, i64* %ptr_new_t
  call i64 @_append_poly(i64 %r21, i64 %r20)
  br label %L1232
L1232:
  %r22 = load i64, i64* %ptr_i
  %r23 = call i64 @_add(i64 %r22, i64 1)
  store i64 %r23, i64* %ptr_i
  br label %L1227
L1229:
  %r24 = load i64, i64* %ptr_new_f
  store i64 %r24, i64* @wire_from
  %r25 = load i64, i64* %ptr_new_t
  store i64 %r25, i64* @wire_to
  ret i64 0
}
define i64 @remove_actor(i64 %arg_n_idx) {
  %ptr_n_idx = alloca i64
  store i64 %arg_n_idx, i64* %ptr_n_idx
  %ptr_w = alloca i64
  %r1 = load i64, i64* @actor_app
  %r2 = load i64, i64* %ptr_n_idx
  %r3 = call i64 @_get(i64 %r1, i64 %r2)
  %r4 = sub i64 0, 1
  %r6 = call i64 @_eq(i64 %r3, i64 %r4)
  %r5 = xor i64 %r6, 1
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L1233, label %L1235
L1233:
  %r8 = load i64, i64* @actor_x
  %r9 = load i64, i64* %ptr_n_idx
  %r10 = call i64 @_get(i64 %r8, i64 %r9)
  %r11 = load i64, i64* @actor_y
  %r12 = load i64, i64* %ptr_n_idx
  %r13 = call i64 @_get(i64 %r11, i64 %r12)
  %r14 = load i64, i64* @actor_w
  %r15 = load i64, i64* %ptr_n_idx
  %r16 = call i64 @_get(i64 %r14, i64 %r15)
  %r17 = load i64, i64* @actor_h
  %r18 = load i64, i64* %ptr_n_idx
  %r19 = call i64 @_get(i64 %r17, i64 %r18)
  %r20 = call i64 @spawn_particles(i64 %r10, i64 %r13, i64 %r16, i64 %r19)
  br label %L1235
L1235:
  %r21 = load i64, i64* @wire_from
  %r22 = call i64 @mensura(i64 %r21)
  %r23 = sub i64 %r22, 1
  store i64 %r23, i64* %ptr_w
  br label %L1236
L1236:
  %r24 = load i64, i64* %ptr_w
  %r26 = icmp sge i64 %r24, 0
  %r25 = zext i1 %r26 to i64
  %r27 = icmp ne i64 %r25, 0
  br i1 %r27, label %L1237, label %L1238
L1237:
  %r28 = load i64, i64* @wire_from
  %r29 = load i64, i64* %ptr_w
  %r30 = call i64 @_get(i64 %r28, i64 %r29)
  %r31 = load i64, i64* %ptr_n_idx
  %r32 = call i64 @_eq(i64 %r30, i64 %r31)
  store i64 1, i64* @.sc.398
  %r34 = icmp eq i64 %r32, 0
  br i1 %r34, label %L1239, label %L1240
L1239:
  %r35 = load i64, i64* @wire_to
  %r36 = load i64, i64* %ptr_w
  %r37 = call i64 @_get(i64 %r35, i64 %r36)
  %r38 = load i64, i64* %ptr_n_idx
  %r39 = call i64 @_eq(i64 %r37, i64 %r38)
  %r40 = icmp ne i64 %r39, 0
  %r41 = zext i1 %r40 to i64
  store i64 %r41, i64* @.sc.398
  br label %L1240
L1240:
  %r33 = load i64, i64* @.sc.398
  %r42 = icmp ne i64 %r33, 0
  br i1 %r42, label %L1241, label %L1243
L1241:
  %r43 = load i64, i64* %ptr_w
  %r44 = call i64 @remove_wire(i64 %r43)
  br label %L1243
L1243:
  %r45 = load i64, i64* %ptr_w
  %r46 = sub i64 %r45, 1
  store i64 %r46, i64* %ptr_w
  br label %L1236
L1238:
  %r47 = sub i64 0, 1
  %r48 = load i64, i64* %ptr_n_idx
  %r49 = load i64, i64* @actor_app
  call i64 @_set(i64 %r49, i64 %r48, i64 %r47)
  %r50 = load i64, i64* @focused_node
  %r51 = load i64, i64* %ptr_n_idx
  %r52 = call i64 @_eq(i64 %r50, i64 %r51)
  %r53 = icmp ne i64 %r52, 0
  br i1 %r53, label %L1244, label %L1246
L1244:
  %r54 = sub i64 0, 1
  store i64 %r54, i64* @focused_node
  br label %L1246
L1246:
  %r55 = load i64, i64* @routing_node
  %r56 = load i64, i64* %ptr_n_idx
  %r57 = call i64 @_eq(i64 %r55, i64 %r56)
  %r58 = icmp ne i64 %r57, 0
  br i1 %r58, label %L1247, label %L1249
L1247:
  %r59 = sub i64 0, 1
  store i64 %r59, i64* @routing_node
  br label %L1249
L1249:
  %r60 = load i64, i64* @resizing_node
  %r61 = load i64, i64* %ptr_n_idx
  %r62 = call i64 @_eq(i64 %r60, i64 %r61)
  %r63 = icmp ne i64 %r62, 0
  br i1 %r63, label %L1250, label %L1252
L1250:
  %r64 = sub i64 0, 1
  store i64 %r64, i64* @resizing_node
  br label %L1252
L1252:
  %r65 = load i64, i64* @paradigm
  %r66 = call i64 @_eq(i64 %r65, i64 1)
  %r67 = icmp ne i64 %r66, 0
  br i1 %r67, label %L1253, label %L1255
L1253:
  %r68 = call i64 @apply_layout()
  br label %L1255
L1255:
  ret i64 0
}
define i64 @clear_screen_fast() {
  %r1 = load i64, i64* @paradigm
  %r2 = call i64 @_eq(i64 %r1, i64 1)
  %r3 = icmp ne i64 %r2, 0
  br i1 %r3, label %L1256, label %L1257
L1256:
  %r4 = load i64, i64* @FB_WIDTH
  %r5 = load i64, i64* @FB_HEIGHT
  %r6 = call i64 @draw_rect(i64 0, i64 0, i64 %r4, i64 %r5, i64 5, i64 5, i64 8)
  br label %L1258
L1257:
  %r7 = load i64, i64* @FB_WIDTH
  %r8 = load i64, i64* @FB_HEIGHT
  %r9 = call i64 @draw_rect(i64 0, i64 0, i64 %r7, i64 %r8, i64 0, i64 0, i64 0)
  br label %L1258
L1258:
  ret i64 0
}
define i64 @render_frame() {
  %ptr_w = alloca i64
  %ptr_f_idx = alloca i64
  %ptr_t_idx = alloca i64
  %ptr_fx = alloca i64
  %ptr_fy = alloca i64
  %ptr_tx = alloca i64
  %ptr_ty = alloca i64
  %ptr_rx = alloca i64
  %ptr_ry = alloca i64
  %ptr_i = alloca i64
  %ptr_h_x = alloca i64
  %ptr_h_y = alloca i64
  %ptr_ob_h = alloca i64
  %ptr_ob_y = alloca i64
  %ptr_prompt = alloca i64
  %r1 = call i64 @clear_screen_fast()
  store i64 0, i64* %ptr_w
  br label %L1259
L1259:
  %r2 = load i64, i64* %ptr_w
  %r3 = load i64, i64* @wire_from
  %r4 = call i64 @mensura(i64 %r3)
  %r6 = icmp slt i64 %r2, %r4
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L1260, label %L1261
L1260:
  %r8 = load i64, i64* @wire_from
  %r9 = load i64, i64* %ptr_w
  %r10 = call i64 @_get(i64 %r8, i64 %r9)
  store i64 %r10, i64* %ptr_f_idx
  %r11 = load i64, i64* @wire_to
  %r12 = load i64, i64* %ptr_w
  %r13 = call i64 @_get(i64 %r11, i64 %r12)
  store i64 %r13, i64* %ptr_t_idx
  %r14 = load i64, i64* @actor_x
  %r15 = load i64, i64* %ptr_f_idx
  %r16 = call i64 @_get(i64 %r14, i64 %r15)
  %r17 = load i64, i64* @actor_w
  %r18 = load i64, i64* %ptr_f_idx
  %r19 = call i64 @_get(i64 %r17, i64 %r18)
  %r20 = sdiv i64 %r19, 2
  %r21 = call i64 @_add(i64 %r16, i64 %r20)
  %r22 = call i64 @world_to_screen_x(i64 %r21)
  store i64 %r22, i64* %ptr_fx
  %r23 = load i64, i64* @actor_y
  %r24 = load i64, i64* %ptr_f_idx
  %r25 = call i64 @_get(i64 %r23, i64 %r24)
  %r26 = load i64, i64* @actor_h
  %r27 = load i64, i64* %ptr_f_idx
  %r28 = call i64 @_get(i64 %r26, i64 %r27)
  %r29 = sdiv i64 %r28, 2
  %r30 = call i64 @_add(i64 %r25, i64 %r29)
  %r31 = call i64 @world_to_screen_y(i64 %r30)
  store i64 %r31, i64* %ptr_fy
  %r32 = load i64, i64* @actor_x
  %r33 = load i64, i64* %ptr_t_idx
  %r34 = call i64 @_get(i64 %r32, i64 %r33)
  %r35 = load i64, i64* @actor_w
  %r36 = load i64, i64* %ptr_t_idx
  %r37 = call i64 @_get(i64 %r35, i64 %r36)
  %r38 = sdiv i64 %r37, 2
  %r39 = call i64 @_add(i64 %r34, i64 %r38)
  %r40 = call i64 @world_to_screen_x(i64 %r39)
  store i64 %r40, i64* %ptr_tx
  %r41 = load i64, i64* @actor_y
  %r42 = load i64, i64* %ptr_t_idx
  %r43 = call i64 @_get(i64 %r41, i64 %r42)
  %r44 = load i64, i64* @actor_h
  %r45 = load i64, i64* %ptr_t_idx
  %r46 = call i64 @_get(i64 %r44, i64 %r45)
  %r47 = sdiv i64 %r46, 2
  %r48 = call i64 @_add(i64 %r43, i64 %r47)
  %r49 = call i64 @world_to_screen_y(i64 %r48)
  store i64 %r49, i64* %ptr_ty
  %r50 = load i64, i64* @paradigm
  %r51 = call i64 @_eq(i64 %r50, i64 1)
  %r52 = icmp ne i64 %r51, 0
  br i1 %r52, label %L1262, label %L1263
L1262:
  %r53 = load i64, i64* %ptr_fx
  %r54 = load i64, i64* %ptr_fy
  %r55 = load i64, i64* %ptr_tx
  %r56 = load i64, i64* %ptr_ty
  %r57 = call i64 @draw_line(i64 %r53, i64 %r54, i64 %r55, i64 %r56, i64 255, i64 0, i64 150)
  br label %L1264
L1263:
  %r58 = load i64, i64* %ptr_fx
  %r59 = load i64, i64* %ptr_fy
  %r60 = load i64, i64* %ptr_tx
  %r61 = load i64, i64* %ptr_ty
  %r62 = call i64 @draw_line(i64 %r58, i64 %r59, i64 %r60, i64 %r61, i64 0, i64 255, i64 100)
  br label %L1264
L1264:
  %r63 = load i64, i64* %ptr_w
  %r64 = call i64 @_add(i64 %r63, i64 1)
  store i64 %r64, i64* %ptr_w
  br label %L1259
L1261:
  %r65 = load i64, i64* @routing_node
  %r66 = sub i64 0, 1
  %r68 = call i64 @_eq(i64 %r65, i64 %r66)
  %r67 = xor i64 %r68, 1
  %r69 = icmp ne i64 %r67, 0
  br i1 %r69, label %L1265, label %L1267
L1265:
  %r70 = load i64, i64* @actor_x
  %r71 = load i64, i64* @routing_node
  %r72 = call i64 @_get(i64 %r70, i64 %r71)
  %r73 = load i64, i64* @actor_w
  %r74 = load i64, i64* @routing_node
  %r75 = call i64 @_get(i64 %r73, i64 %r74)
  %r76 = sdiv i64 %r75, 2
  %r77 = call i64 @_add(i64 %r72, i64 %r76)
  %r78 = call i64 @world_to_screen_x(i64 %r77)
  store i64 %r78, i64* %ptr_rx
  %r79 = load i64, i64* @actor_y
  %r80 = load i64, i64* @routing_node
  %r81 = call i64 @_get(i64 %r79, i64 %r80)
  %r82 = load i64, i64* @actor_h
  %r83 = load i64, i64* @routing_node
  %r84 = call i64 @_get(i64 %r82, i64 %r83)
  %r85 = sdiv i64 %r84, 2
  %r86 = call i64 @_add(i64 %r81, i64 %r85)
  %r87 = call i64 @world_to_screen_y(i64 %r86)
  store i64 %r87, i64* %ptr_ry
  %r88 = load i64, i64* %ptr_rx
  %r89 = load i64, i64* %ptr_ry
  %r90 = load i64, i64* @mouse_x
  %r91 = load i64, i64* @mouse_y
  %r92 = call i64 @draw_line(i64 %r88, i64 %r89, i64 %r90, i64 %r91, i64 255, i64 255, i64 0)
  br label %L1267
L1267:
  store i64 0, i64* %ptr_i
  br label %L1268
L1268:
  %r93 = load i64, i64* %ptr_i
  %r94 = load i64, i64* @actor_x
  %r95 = call i64 @mensura(i64 %r94)
  %r97 = icmp slt i64 %r93, %r95
  %r96 = zext i1 %r97 to i64
  %r98 = icmp ne i64 %r96, 0
  br i1 %r98, label %L1269, label %L1270
L1269:
  %r99 = load i64, i64* @actor_app
  %r100 = load i64, i64* %ptr_i
  %r101 = call i64 @_get(i64 %r99, i64 %r100)
  %r102 = sub i64 0, 1
  %r104 = call i64 @_eq(i64 %r101, i64 %r102)
  %r103 = xor i64 %r104, 1
  %r105 = icmp ne i64 %r103, 0
  br i1 %r105, label %L1271, label %L1273
L1271:
  %r106 = load i64, i64* @focused_node
  %r107 = load i64, i64* %ptr_i
  %r108 = call i64 @_eq(i64 %r106, i64 %r107)
  store i64 1, i64* @.sc.399
  %r110 = icmp eq i64 %r108, 0
  br i1 %r110, label %L1274, label %L1275
L1274:
  %r111 = load i64, i64* @routing_node
  %r112 = load i64, i64* %ptr_i
  %r113 = call i64 @_eq(i64 %r111, i64 %r112)
  %r114 = icmp ne i64 %r113, 0
  %r115 = zext i1 %r114 to i64
  store i64 %r115, i64* @.sc.399
  br label %L1275
L1275:
  %r109 = load i64, i64* @.sc.399
  %r116 = icmp ne i64 %r109, 0
  br i1 %r116, label %L1276, label %L1277
L1276:
  %r117 = load i64, i64* @actor_x
  %r118 = load i64, i64* %ptr_i
  %r119 = call i64 @_get(i64 %r117, i64 %r118)
  %r120 = load i64, i64* @actor_y
  %r121 = load i64, i64* %ptr_i
  %r122 = call i64 @_get(i64 %r120, i64 %r121)
  %r123 = load i64, i64* @actor_w
  %r124 = load i64, i64* %ptr_i
  %r125 = call i64 @_get(i64 %r123, i64 %r124)
  %r126 = load i64, i64* @actor_h
  %r127 = load i64, i64* %ptr_i
  %r128 = call i64 @_get(i64 %r126, i64 %r127)
  %r129 = call i64 @draw_zui_node(i64 %r119, i64 %r122, i64 %r125, i64 %r128, i64 0, i64 255, i64 255)
  %r130 = load i64, i64* @paradigm
  %r131 = call i64 @_eq(i64 %r130, i64 0)
  %r132 = icmp ne i64 %r131, 0
  br i1 %r132, label %L1279, label %L1281
L1279:
  %r133 = load i64, i64* @actor_x
  %r134 = load i64, i64* %ptr_i
  %r135 = call i64 @_get(i64 %r133, i64 %r134)
  %r136 = load i64, i64* @actor_w
  %r137 = load i64, i64* %ptr_i
  %r138 = call i64 @_get(i64 %r136, i64 %r137)
  %r139 = call i64 @_add(i64 %r135, i64 %r138)
  %r140 = sub i64 %r139, 15
  %r141 = call i64 @world_to_screen_x(i64 %r140)
  store i64 %r141, i64* %ptr_h_x
  %r142 = load i64, i64* @actor_y
  %r143 = load i64, i64* %ptr_i
  %r144 = call i64 @_get(i64 %r142, i64 %r143)
  %r145 = load i64, i64* @actor_h
  %r146 = load i64, i64* %ptr_i
  %r147 = call i64 @_get(i64 %r145, i64 %r146)
  %r148 = call i64 @_add(i64 %r144, i64 %r147)
  %r149 = sub i64 %r148, 15
  %r150 = call i64 @world_to_screen_y(i64 %r149)
  store i64 %r150, i64* %ptr_h_y
  %r151 = load i64, i64* %ptr_h_x
  %r152 = load i64, i64* %ptr_h_y
  %r153 = call i64 @scale_size(i64 15)
  %r154 = call i64 @scale_size(i64 15)
  %r155 = call i64 @draw_rect(i64 %r151, i64 %r152, i64 %r153, i64 %r154, i64 0, i64 255, i64 255)
  br label %L1281
L1281:
  br label %L1278
L1277:
  %r156 = load i64, i64* @actor_x
  %r157 = load i64, i64* %ptr_i
  %r158 = call i64 @_get(i64 %r156, i64 %r157)
  %r159 = load i64, i64* @actor_y
  %r160 = load i64, i64* %ptr_i
  %r161 = call i64 @_get(i64 %r159, i64 %r160)
  %r162 = load i64, i64* @actor_w
  %r163 = load i64, i64* %ptr_i
  %r164 = call i64 @_get(i64 %r162, i64 %r163)
  %r165 = load i64, i64* @actor_h
  %r166 = load i64, i64* %ptr_i
  %r167 = call i64 @_get(i64 %r165, i64 %r166)
  %r168 = call i64 @draw_zui_node(i64 %r158, i64 %r161, i64 %r164, i64 %r167, i64 30, i64 30, i64 40)
  br label %L1278
L1278:
  %r169 = load i64, i64* @actor_x
  %r170 = load i64, i64* %ptr_i
  %r171 = call i64 @_get(i64 %r169, i64 %r170)
  %r172 = call i64 @_add(i64 %r171, i64 10)
  %r173 = load i64, i64* @actor_y
  %r174 = load i64, i64* %ptr_i
  %r175 = call i64 @_get(i64 %r173, i64 %r174)
  %r176 = call i64 @_add(i64 %r175, i64 10)
  %r177 = load i64, i64* @actor_w
  %r178 = load i64, i64* %ptr_i
  %r179 = call i64 @_get(i64 %r177, i64 %r178)
  %r180 = sub i64 %r179, 20
  %r181 = load i64, i64* @actor_h
  %r182 = load i64, i64* %ptr_i
  %r183 = call i64 @_get(i64 %r181, i64 %r182)
  %r184 = sub i64 %r183, 20
  %r185 = load i64, i64* @actor_text
  %r186 = load i64, i64* %ptr_i
  %r187 = call i64 @_get(i64 %r185, i64 %r186)
  %r188 = call i64 @draw_zui_string_clipped(i64 %r172, i64 %r176, i64 %r180, i64 %r184, i64 1, i64 %r187, i64 0, i64 255, i64 0)
  br label %L1273
L1273:
  %r189 = load i64, i64* %ptr_i
  %r190 = call i64 @_add(i64 %r189, i64 1)
  store i64 %r190, i64* %ptr_i
  br label %L1268
L1270:
  %r191 = call i64 @render_particles()
  store i64 40, i64* %ptr_ob_h
  %r192 = load i64, i64* @FB_HEIGHT
  %r193 = load i64, i64* %ptr_ob_h
  %r194 = sub i64 %r192, %r193
  %r195 = sub i64 %r194, 10
  store i64 %r195, i64* %ptr_ob_y
  %r196 = load i64, i64* %ptr_ob_y
  %r197 = load i64, i64* @FB_WIDTH
  %r198 = sub i64 %r197, 20
  %r199 = load i64, i64* %ptr_ob_h
  %r200 = call i64 @draw_rect(i64 10, i64 %r196, i64 %r198, i64 %r199, i64 15, i64 15, i64 20)
  %r201 = load i64, i64* @focused_node
  %r202 = sub i64 0, 1
  %r203 = call i64 @_eq(i64 %r201, i64 %r202)
  %r204 = icmp ne i64 %r203, 0
  br i1 %r204, label %L1282, label %L1283
L1282:
  %r205 = load i64, i64* %ptr_ob_y
  %r206 = load i64, i64* @FB_WIDTH
  %r207 = sub i64 %r206, 20
  %r208 = call i64 @draw_rect(i64 10, i64 %r205, i64 %r207, i64 2, i64 255, i64 0, i64 255)
  br label %L1284
L1283:
  %r209 = load i64, i64* %ptr_ob_y
  %r210 = load i64, i64* @FB_WIDTH
  %r211 = sub i64 %r210, 20
  %r212 = call i64 @draw_rect(i64 10, i64 %r209, i64 %r211, i64 2, i64 50, i64 50, i64 50)
  br label %L1284
L1284:
  %r213 = getelementptr [19 x i8], [19 x i8]* @.str.400, i64 0, i64 0
  %r214 = ptrtoint i8* %r213 to i64
  store i64 %r214, i64* %ptr_prompt
  %r215 = load i64, i64* @paradigm
  %r216 = call i64 @_eq(i64 %r215, i64 0)
  %r217 = icmp ne i64 %r216, 0
  br i1 %r217, label %L1285, label %L1287
L1285:
  %r218 = getelementptr [14 x i8], [14 x i8]* @.str.401, i64 0, i64 0
  %r219 = ptrtoint i8* %r218 to i64
  store i64 %r219, i64* %ptr_prompt
  br label %L1287
L1287:
  %r220 = load i64, i64* @focused_node
  %r221 = sub i64 0, 1
  %r222 = call i64 @_eq(i64 %r220, i64 %r221)
  %r223 = icmp ne i64 %r222, 0
  br i1 %r223, label %L1288, label %L1289
L1288:
  %r224 = load i64, i64* %ptr_prompt
  %r225 = load i64, i64* @omni_text
  %r226 = call i64 @_add(i64 %r224, i64 %r225)
  %r227 = getelementptr [2 x i8], [2 x i8]* @.str.402, i64 0, i64 0
  %r228 = ptrtoint i8* %r227 to i64
  %r229 = call i64 @_add(i64 %r226, i64 %r228)
  store i64 %r229, i64* %ptr_prompt
  br label %L1290
L1289:
  %r230 = load i64, i64* %ptr_prompt
  %r231 = load i64, i64* @omni_text
  %r232 = call i64 @_add(i64 %r230, i64 %r231)
  store i64 %r232, i64* %ptr_prompt
  br label %L1290
L1290:
  %r233 = load i64, i64* %ptr_ob_y
  %r234 = call i64 @_add(i64 %r233, i64 12)
  %r235 = load i64, i64* %ptr_prompt
  %r236 = call i64 @draw_raw_string(i64 20, i64 %r234, i64 2, i64 %r235, i64 255, i64 255, i64 255)
  %r237 = call i64 @draw_reticle()
  %r238 = call i64 @swap_buffers()
  ret i64 0
}
define i64 @get_hovered_node(i64 %arg_wx, i64 %arg_wy) {
  %ptr_wx = alloca i64
  store i64 %arg_wx, i64* %ptr_wx
  %ptr_wy = alloca i64
  store i64 %arg_wy, i64* %ptr_wy
  %ptr_i = alloca i64
  %ptr_nx = alloca i64
  %ptr_ny = alloca i64
  %ptr_nw = alloca i64
  %ptr_nh = alloca i64
  %r1 = load i64, i64* @actor_x
  %r2 = call i64 @mensura(i64 %r1)
  %r3 = sub i64 %r2, 1
  store i64 %r3, i64* %ptr_i
  br label %L1291
L1291:
  %r4 = load i64, i64* %ptr_i
  %r6 = icmp sge i64 %r4, 0
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L1292, label %L1293
L1292:
  %r8 = load i64, i64* @actor_app
  %r9 = load i64, i64* %ptr_i
  %r10 = call i64 @_get(i64 %r8, i64 %r9)
  %r11 = sub i64 0, 1
  %r13 = call i64 @_eq(i64 %r10, i64 %r11)
  %r12 = xor i64 %r13, 1
  %r14 = icmp ne i64 %r12, 0
  br i1 %r14, label %L1294, label %L1296
L1294:
  %r15 = load i64, i64* @actor_x
  %r16 = load i64, i64* %ptr_i
  %r17 = call i64 @_get(i64 %r15, i64 %r16)
  store i64 %r17, i64* %ptr_nx
  %r18 = load i64, i64* @actor_y
  %r19 = load i64, i64* %ptr_i
  %r20 = call i64 @_get(i64 %r18, i64 %r19)
  store i64 %r20, i64* %ptr_ny
  %r21 = load i64, i64* @actor_w
  %r22 = load i64, i64* %ptr_i
  %r23 = call i64 @_get(i64 %r21, i64 %r22)
  store i64 %r23, i64* %ptr_nw
  %r24 = load i64, i64* @actor_h
  %r25 = load i64, i64* %ptr_i
  %r26 = call i64 @_get(i64 %r24, i64 %r25)
  store i64 %r26, i64* %ptr_nh
  %r27 = load i64, i64* %ptr_wx
  %r28 = load i64, i64* %ptr_nx
  %r30 = icmp sge i64 %r27, %r28
  %r29 = zext i1 %r30 to i64
  store i64 0, i64* @.sc.405
  %r32 = icmp ne i64 %r29, 0
  br i1 %r32, label %L1297, label %L1298
L1297:
  %r33 = load i64, i64* %ptr_wx
  %r34 = load i64, i64* %ptr_nx
  %r35 = load i64, i64* %ptr_nw
  %r36 = call i64 @_add(i64 %r34, i64 %r35)
  %r38 = icmp sle i64 %r33, %r36
  %r37 = zext i1 %r38 to i64
  %r39 = icmp ne i64 %r37, 0
  %r40 = zext i1 %r39 to i64
  store i64 %r40, i64* @.sc.405
  br label %L1298
L1298:
  %r31 = load i64, i64* @.sc.405
  store i64 0, i64* @.sc.404
  %r42 = icmp ne i64 %r31, 0
  br i1 %r42, label %L1299, label %L1300
L1299:
  %r43 = load i64, i64* %ptr_wy
  %r44 = load i64, i64* %ptr_ny
  %r46 = icmp sge i64 %r43, %r44
  %r45 = zext i1 %r46 to i64
  %r47 = icmp ne i64 %r45, 0
  %r48 = zext i1 %r47 to i64
  store i64 %r48, i64* @.sc.404
  br label %L1300
L1300:
  %r41 = load i64, i64* @.sc.404
  store i64 0, i64* @.sc.403
  %r50 = icmp ne i64 %r41, 0
  br i1 %r50, label %L1301, label %L1302
L1301:
  %r51 = load i64, i64* %ptr_wy
  %r52 = load i64, i64* %ptr_ny
  %r53 = load i64, i64* %ptr_nh
  %r54 = call i64 @_add(i64 %r52, i64 %r53)
  %r56 = icmp sle i64 %r51, %r54
  %r55 = zext i1 %r56 to i64
  %r57 = icmp ne i64 %r55, 0
  %r58 = zext i1 %r57 to i64
  store i64 %r58, i64* @.sc.403
  br label %L1302
L1302:
  %r49 = load i64, i64* @.sc.403
  %r59 = icmp ne i64 %r49, 0
  br i1 %r59, label %L1303, label %L1305
L1303:
  %r60 = load i64, i64* %ptr_i
  ret i64 %r60
  br label %L1305
L1305:
  br label %L1296
L1296:
  %r61 = load i64, i64* %ptr_i
  %r62 = sub i64 %r61, 1
  store i64 %r62, i64* %ptr_i
  br label %L1291
L1293:
  %r63 = sub i64 0, 1
  ret i64 %r63
  ret i64 0
}
define i64 @get_hovered_corner(i64 %arg_wx, i64 %arg_wy) {
  %ptr_wx = alloca i64
  store i64 %arg_wx, i64* %ptr_wx
  %ptr_wy = alloca i64
  store i64 %arg_wy, i64* %ptr_wy
  %ptr_i = alloca i64
  %ptr_nx = alloca i64
  %ptr_ny = alloca i64
  %ptr_nw = alloca i64
  %ptr_nh = alloca i64
  %r1 = load i64, i64* @actor_x
  %r2 = call i64 @mensura(i64 %r1)
  %r3 = sub i64 %r2, 1
  store i64 %r3, i64* %ptr_i
  br label %L1306
L1306:
  %r4 = load i64, i64* %ptr_i
  %r6 = icmp sge i64 %r4, 0
  %r5 = zext i1 %r6 to i64
  %r7 = icmp ne i64 %r5, 0
  br i1 %r7, label %L1307, label %L1308
L1307:
  %r8 = load i64, i64* @actor_app
  %r9 = load i64, i64* %ptr_i
  %r10 = call i64 @_get(i64 %r8, i64 %r9)
  %r11 = sub i64 0, 1
  %r13 = call i64 @_eq(i64 %r10, i64 %r11)
  %r12 = xor i64 %r13, 1
  %r14 = icmp ne i64 %r12, 0
  br i1 %r14, label %L1309, label %L1311
L1309:
  %r15 = load i64, i64* @actor_x
  %r16 = load i64, i64* %ptr_i
  %r17 = call i64 @_get(i64 %r15, i64 %r16)
  store i64 %r17, i64* %ptr_nx
  %r18 = load i64, i64* @actor_y
  %r19 = load i64, i64* %ptr_i
  %r20 = call i64 @_get(i64 %r18, i64 %r19)
  store i64 %r20, i64* %ptr_ny
  %r21 = load i64, i64* @actor_w
  %r22 = load i64, i64* %ptr_i
  %r23 = call i64 @_get(i64 %r21, i64 %r22)
  store i64 %r23, i64* %ptr_nw
  %r24 = load i64, i64* @actor_h
  %r25 = load i64, i64* %ptr_i
  %r26 = call i64 @_get(i64 %r24, i64 %r25)
  store i64 %r26, i64* %ptr_nh
  %r27 = load i64, i64* %ptr_wx
  %r28 = load i64, i64* %ptr_nx
  %r29 = load i64, i64* %ptr_nw
  %r30 = call i64 @_add(i64 %r28, i64 %r29)
  %r31 = sub i64 %r30, 20
  %r33 = icmp sge i64 %r27, %r31
  %r32 = zext i1 %r33 to i64
  store i64 0, i64* @.sc.408
  %r35 = icmp ne i64 %r32, 0
  br i1 %r35, label %L1312, label %L1313
L1312:
  %r36 = load i64, i64* %ptr_wx
  %r37 = load i64, i64* %ptr_nx
  %r38 = load i64, i64* %ptr_nw
  %r39 = call i64 @_add(i64 %r37, i64 %r38)
  %r41 = icmp sle i64 %r36, %r39
  %r40 = zext i1 %r41 to i64
  %r42 = icmp ne i64 %r40, 0
  %r43 = zext i1 %r42 to i64
  store i64 %r43, i64* @.sc.408
  br label %L1313
L1313:
  %r34 = load i64, i64* @.sc.408
  store i64 0, i64* @.sc.407
  %r45 = icmp ne i64 %r34, 0
  br i1 %r45, label %L1314, label %L1315
L1314:
  %r46 = load i64, i64* %ptr_wy
  %r47 = load i64, i64* %ptr_ny
  %r48 = load i64, i64* %ptr_nh
  %r49 = call i64 @_add(i64 %r47, i64 %r48)
  %r50 = sub i64 %r49, 20
  %r52 = icmp sge i64 %r46, %r50
  %r51 = zext i1 %r52 to i64
  %r53 = icmp ne i64 %r51, 0
  %r54 = zext i1 %r53 to i64
  store i64 %r54, i64* @.sc.407
  br label %L1315
L1315:
  %r44 = load i64, i64* @.sc.407
  store i64 0, i64* @.sc.406
  %r56 = icmp ne i64 %r44, 0
  br i1 %r56, label %L1316, label %L1317
L1316:
  %r57 = load i64, i64* %ptr_wy
  %r58 = load i64, i64* %ptr_ny
  %r59 = load i64, i64* %ptr_nh
  %r60 = call i64 @_add(i64 %r58, i64 %r59)
  %r62 = icmp sle i64 %r57, %r60
  %r61 = zext i1 %r62 to i64
  %r63 = icmp ne i64 %r61, 0
  %r64 = zext i1 %r63 to i64
  store i64 %r64, i64* @.sc.406
  br label %L1317
L1317:
  %r55 = load i64, i64* @.sc.406
  %r65 = icmp ne i64 %r55, 0
  br i1 %r65, label %L1318, label %L1320
L1318:
  %r66 = load i64, i64* %ptr_i
  ret i64 %r66
  br label %L1320
L1320:
  br label %L1311
L1311:
  %r67 = load i64, i64* %ptr_i
  %r68 = sub i64 %r67, 1
  store i64 %r68, i64* %ptr_i
  br label %L1306
L1308:
  %r69 = sub i64 0, 1
  ret i64 %r69
  ret i64 0
}
define i64 @send_msg(i64 %arg_target_id, i64 %arg_msg) {
  %ptr_target_id = alloca i64
  store i64 %arg_target_id, i64* %ptr_target_id
  %ptr_msg = alloca i64
  store i64 %arg_msg, i64* %ptr_msg
  %r1 = load i64, i64* %ptr_target_id
  %r3 = icmp sge i64 %r1, 0
  %r2 = zext i1 %r3 to i64
  store i64 0, i64* @.sc.409
  %r5 = icmp ne i64 %r2, 0
  br i1 %r5, label %L1321, label %L1322
L1321:
  %r6 = load i64, i64* %ptr_target_id
  %r7 = load i64, i64* @actor_mailbox
  %r8 = call i64 @mensura(i64 %r7)
  %r10 = icmp slt i64 %r6, %r8
  %r9 = zext i1 %r10 to i64
  %r11 = icmp ne i64 %r9, 0
  %r12 = zext i1 %r11 to i64
  store i64 %r12, i64* @.sc.409
  br label %L1322
L1322:
  %r4 = load i64, i64* @.sc.409
  %r13 = icmp ne i64 %r4, 0
  br i1 %r13, label %L1323, label %L1325
L1323:
  %r14 = load i64, i64* @actor_mailbox
  %r15 = load i64, i64* %ptr_target_id
  %r16 = call i64 @_get(i64 %r14, i64 %r15)
  %r17 = load i64, i64* %ptr_msg
  %r18 = call i64 @_add(i64 %r16, i64 %r17)
  %r19 = getelementptr [2 x i8], [2 x i8]* @.str.410, i64 0, i64 0
  %r20 = ptrtoint i8* %r19 to i64
  %r21 = call i64 @_add(i64 %r18, i64 %r20)
  %r22 = load i64, i64* %ptr_target_id
  %r23 = load i64, i64* @actor_mailbox
  call i64 @_set(i64 %r23, i64 %r22, i64 %r21)
  br label %L1325
L1325:
  ret i64 0
}
define i64 @scheduler_tick() {
  %ptr_i = alloca i64
  %ptr_is_processing = alloca i64
  %ptr_box = alloca i64
  %ptr_box_len = alloca i64
  %ptr_m_idx = alloca i64
  %ptr_msg = alloca i64
  %ptr_c = alloca i64
  %ptr_rem_len = alloca i64
  %ptr_should_clear = alloca i64
  %ptr_t_len = alloca i64
  %ptr_c_len = alloca i64
  %ptr_cmd = alloca i64
  %ptr_out = alloca i64
  %ptr_app_mode = alloca i64
  %ptr_prefix_run = alloca i64
  %ptr_prefix_rev = alloca i64
  %ptr_prefix_read = alloca i64
  %ptr_prefix_edit = alloca i64
  %ptr_n = alloca i64
  %ptr_fname = alloca i64
  %ptr_target = alloca i64
  %ptr_file_data = alloca i64
  %ptr_bus = alloca i64
  %ptr_slot = alloca i64
  %ptr_vendor = alloca i64
  %ptr_device = alloca i64
  %ptr_mmio = alloca i64
  %ptr_frame = alloca i64
  %ptr_arp = alloca i64
  %ptr_status_ptr = alloca i64
  %ptr_timeout = alloca i64
  %ptr_done = alloca i64
  %ptr_head = alloca i64
  %ptr_pkt = alloca i64
  %ptr_j = alloca i64
  %ptr_dump = alloca i64
  %ptr_b = alloca i64
  %ptr_z = alloca i64
  %ptr_ip = alloca i64
  %ptr_udp = alloca i64
  %ptr_dns = alloca i64
  %ptr_flush = alloca i64
  %ptr_rx_timeout = alloca i64
  %ptr_reply_pkt = alloca i64
  %ptr_yield = alloca i64
  %ptr_tmp_pkt = alloca i64
  %ptr_e_type = alloca i64
  %ptr_proto = alloca i64
  %ptr_ip1 = alloca i64
  %ptr_ip2 = alloca i64
  %ptr_ip3 = alloca i64
  %ptr_ip4 = alloca i64
  %ptr_f = alloca i64
  %ptr_ral = alloca i64
  %ptr_rah = alloca i64
  %ptr_tcp = alloca i64
  %ptr_caught = alloca i64
  %ptr_e_hi = alloca i64
  %ptr_e_lo = alloca i64
  %ptr_k = alloca i64
  %ptr_my_port = alloca i64
  %ptr_my_seq = alloca i64
  %ptr_tx_frame = alloca i64
  %ptr_ip_ihl_ver = alloca i64
  %ptr_ip_hdr_len = alloca i64
  %ptr_tcp_start = alloca i64
  %ptr_flags = alloca i64
  %ptr_s_seq1 = alloca i64
  %ptr_s_seq2 = alloca i64
  %ptr_s_seq3 = alloca i64
  %ptr_s_seq4 = alloca i64
  %ptr_slirp_delay = alloca i64
  %ptr_http_pkt = alloca i64
  %ptr_yield_rx = alloca i64
  %ptr_h_pkt = alloca i64
  %ptr_e_h_hi = alloca i64
  %ptr_e_h_lo = alloca i64
  %ptr_h_proto = alloca i64
  %ptr_h_ihl = alloca i64
  %ptr_h_ip_len = alloca i64
  %ptr_h_tcp_start = alloca i64
  %ptr_data_off = alloca i64
  %ptr_h_tcp_hdr_len = alloca i64
  %ptr_ip_b1 = alloca i64
  %ptr_ip_b2 = alloca i64
  %ptr_ip_tot_len = alloca i64
  %ptr_p_size = alloca i64
  %ptr_pl_off = alloca i64
  %ptr_p_i = alloca i64
  %ptr_bc = alloca i64
  %ptr_dmp = alloca i64
  %ptr_d_b = alloca i64
  %ptr_routed = alloca i64
  %ptr_w = alloca i64
  %ptr_np = alloca i64
  %ptr_prefix_ipc = alloca i64
  store i64 0, i64* %ptr_i
  br label %L1326
L1326:
  %r1 = load i64, i64* %ptr_i
  %r2 = load i64, i64* @actor_budget
  %r3 = call i64 @mensura(i64 %r2)
  %r5 = icmp slt i64 %r1, %r3
  %r4 = zext i1 %r5 to i64
  %r6 = icmp ne i64 %r4, 0
  br i1 %r6, label %L1327, label %L1328
L1327:
  %r7 = load i64, i64* %ptr_i
  %r8 = load i64, i64* @actor_budget
  call i64 @_set(i64 %r8, i64 %r7, i64 5)
  %r9 = load i64, i64* %ptr_i
  %r10 = call i64 @_add(i64 %r9, i64 1)
  store i64 %r10, i64* %ptr_i
  br label %L1326
L1328:
  store i64 0, i64* %ptr_i
  br label %L1329
L1329:
  %r11 = load i64, i64* %ptr_i
  %r12 = load i64, i64* @actor_mailbox
  %r13 = call i64 @mensura(i64 %r12)
  %r15 = icmp slt i64 %r11, %r13
  %r14 = zext i1 %r15 to i64
  %r16 = icmp ne i64 %r14, 0
  br i1 %r16, label %L1330, label %L1331
L1330:
  %r17 = load i64, i64* @actor_app
  %r18 = load i64, i64* %ptr_i
  %r19 = call i64 @_get(i64 %r17, i64 %r18)
  %r20 = sub i64 0, 1
  %r22 = call i64 @_eq(i64 %r19, i64 %r20)
  %r21 = xor i64 %r22, 1
  %r23 = icmp ne i64 %r21, 0
  br i1 %r23, label %L1332, label %L1334
L1332:
  store i64 1, i64* %ptr_is_processing
  br label %L1335
L1335:
  %r24 = load i64, i64* %ptr_is_processing
  %r25 = call i64 @_eq(i64 %r24, i64 1)
  %r26 = icmp ne i64 %r25, 0
  br i1 %r26, label %L1336, label %L1337
L1336:
  %r27 = load i64, i64* @actor_budget
  %r28 = load i64, i64* %ptr_i
  %r29 = call i64 @_get(i64 %r27, i64 %r28)
  %r31 = icmp sle i64 %r29, 0
  %r30 = zext i1 %r31 to i64
  %r32 = icmp ne i64 %r30, 0
  br i1 %r32, label %L1338, label %L1339
L1338:
  store i64 0, i64* %ptr_is_processing
  br label %L1340
L1339:
  %r33 = load i64, i64* @actor_mailbox
  %r34 = load i64, i64* %ptr_i
  %r35 = call i64 @_get(i64 %r33, i64 %r34)
  store i64 %r35, i64* %ptr_box
  %r36 = load i64, i64* %ptr_box
  %r37 = call i64 @mensura(i64 %r36)
  store i64 %r37, i64* %ptr_box_len
  %r38 = load i64, i64* %ptr_box_len
  %r40 = icmp sgt i64 %r38, 0
  %r39 = zext i1 %r40 to i64
  %r41 = icmp ne i64 %r39, 0
  br i1 %r41, label %L1341, label %L1342
L1341:
  store i64 0, i64* %ptr_m_idx
  %r42 = getelementptr [1 x i8], [1 x i8]* @.str.411, i64 0, i64 0
  %r43 = ptrtoint i8* %r42 to i64
  store i64 %r43, i64* %ptr_msg
  br label %L1344
L1344:
  %r44 = load i64, i64* %ptr_m_idx
  %r45 = load i64, i64* %ptr_box_len
  %r47 = icmp slt i64 %r44, %r45
  %r46 = zext i1 %r47 to i64
  %r48 = icmp ne i64 %r46, 0
  br i1 %r48, label %L1345, label %L1346
L1345:
  %r49 = load i64, i64* %ptr_box
  %r50 = load i64, i64* %ptr_m_idx
  %r51 = call i64 @pars(i64 %r49, i64 %r50, i64 1)
  store i64 %r51, i64* %ptr_c
  %r52 = load i64, i64* %ptr_c
  %r53 = getelementptr [2 x i8], [2 x i8]* @.str.412, i64 0, i64 0
  %r54 = ptrtoint i8* %r53 to i64
  %r55 = call i64 @_eq(i64 %r52, i64 %r54)
  %r56 = icmp ne i64 %r55, 0
  br i1 %r56, label %L1347, label %L1348
L1347:
  %r57 = load i64, i64* %ptr_box_len
  store i64 %r57, i64* %ptr_m_idx
  br label %L1349
L1348:
  %r58 = load i64, i64* %ptr_msg
  %r59 = load i64, i64* %ptr_c
  %r60 = call i64 @_add(i64 %r58, i64 %r59)
  store i64 %r60, i64* %ptr_msg
  br label %L1349
L1349:
  %r61 = load i64, i64* %ptr_m_idx
  %r62 = call i64 @_add(i64 %r61, i64 1)
  store i64 %r62, i64* %ptr_m_idx
  br label %L1344
L1346:
  %r63 = load i64, i64* %ptr_box_len
  %r64 = load i64, i64* %ptr_msg
  %r65 = call i64 @mensura(i64 %r64)
  %r66 = sub i64 %r63, %r65
  %r67 = sub i64 %r66, 1
  store i64 %r67, i64* %ptr_rem_len
  %r68 = load i64, i64* %ptr_rem_len
  %r70 = icmp sgt i64 %r68, 0
  %r69 = zext i1 %r70 to i64
  %r71 = icmp ne i64 %r69, 0
  br i1 %r71, label %L1350, label %L1351
L1350:
  %r72 = load i64, i64* %ptr_box
  %r73 = load i64, i64* %ptr_msg
  %r74 = call i64 @mensura(i64 %r73)
  %r75 = call i64 @_add(i64 %r74, i64 1)
  %r76 = load i64, i64* %ptr_rem_len
  %r77 = call i64 @pars(i64 %r72, i64 %r75, i64 %r76)
  %r78 = load i64, i64* %ptr_i
  %r79 = load i64, i64* @actor_mailbox
  call i64 @_set(i64 %r79, i64 %r78, i64 %r77)
  br label %L1352
L1351:
  %r80 = getelementptr [1 x i8], [1 x i8]* @.str.413, i64 0, i64 0
  %r81 = ptrtoint i8* %r80 to i64
  %r82 = load i64, i64* %ptr_i
  %r83 = load i64, i64* @actor_mailbox
  call i64 @_set(i64 %r83, i64 %r82, i64 %r81)
  br label %L1352
L1352:
  store i64 0, i64* %ptr_should_clear
  %r84 = load i64, i64* %ptr_msg
  %r85 = getelementptr [10 x i8], [10 x i8]* @.str.414, i64 0, i64 0
  %r86 = ptrtoint i8* %r85 to i64
  %r87 = call i64 @_eq(i64 %r84, i64 %r86)
  %r88 = icmp ne i64 %r87, 0
  br i1 %r88, label %L1353, label %L1354
L1353:
  %r89 = load i64, i64* @actor_text
  %r90 = load i64, i64* %ptr_i
  %r91 = call i64 @_get(i64 %r89, i64 %r90)
  %r92 = call i64 @mensura(i64 %r91)
  store i64 %r92, i64* %ptr_t_len
  %r93 = load i64, i64* @actor_cmd
  %r94 = load i64, i64* %ptr_i
  %r95 = call i64 @_get(i64 %r93, i64 %r94)
  %r96 = call i64 @mensura(i64 %r95)
  store i64 %r96, i64* %ptr_c_len
  %r97 = load i64, i64* %ptr_c_len
  %r99 = icmp sgt i64 %r97, 1
  %r98 = zext i1 %r99 to i64
  %r100 = icmp ne i64 %r98, 0
  br i1 %r100, label %L1356, label %L1357
L1356:
  %r101 = load i64, i64* @actor_text
  %r102 = load i64, i64* %ptr_i
  %r103 = call i64 @_get(i64 %r101, i64 %r102)
  %r104 = load i64, i64* %ptr_t_len
  %r105 = sub i64 %r104, 1
  %r106 = call i64 @pars(i64 %r103, i64 0, i64 %r105)
  %r107 = load i64, i64* %ptr_i
  %r108 = load i64, i64* @actor_text
  call i64 @_set(i64 %r108, i64 %r107, i64 %r106)
  %r109 = load i64, i64* @actor_cmd
  %r110 = load i64, i64* %ptr_i
  %r111 = call i64 @_get(i64 %r109, i64 %r110)
  %r112 = load i64, i64* %ptr_c_len
  %r113 = sub i64 %r112, 1
  %r114 = call i64 @pars(i64 %r111, i64 0, i64 %r113)
  %r115 = load i64, i64* %ptr_i
  %r116 = load i64, i64* @actor_cmd
  call i64 @_set(i64 %r116, i64 %r115, i64 %r114)
  br label %L1358
L1357:
  %r117 = load i64, i64* %ptr_c_len
  %r118 = call i64 @_eq(i64 %r117, i64 1)
  %r119 = icmp ne i64 %r118, 0
  br i1 %r119, label %L1359, label %L1361
L1359:
  %r120 = load i64, i64* @actor_text
  %r121 = load i64, i64* %ptr_i
  %r122 = call i64 @_get(i64 %r120, i64 %r121)
  %r123 = load i64, i64* %ptr_t_len
  %r124 = sub i64 %r123, 1
  %r125 = call i64 @pars(i64 %r122, i64 0, i64 %r124)
  %r126 = load i64, i64* %ptr_i
  %r127 = load i64, i64* @actor_text
  call i64 @_set(i64 %r127, i64 %r126, i64 %r125)
  %r128 = getelementptr [1 x i8], [1 x i8]* @.str.415, i64 0, i64 0
  %r129 = ptrtoint i8* %r128 to i64
  %r130 = load i64, i64* %ptr_i
  %r131 = load i64, i64* @actor_cmd
  call i64 @_set(i64 %r131, i64 %r130, i64 %r129)
  br label %L1361
L1361:
  br label %L1358
L1358:
  br label %L1355
L1354:
  %r132 = load i64, i64* %ptr_msg
  %r133 = getelementptr [6 x i8], [6 x i8]* @.str.416, i64 0, i64 0
  %r134 = ptrtoint i8* %r133 to i64
  %r135 = call i64 @_eq(i64 %r132, i64 %r134)
  %r136 = icmp ne i64 %r135, 0
  br i1 %r136, label %L1362, label %L1363
L1362:
  %r137 = load i64, i64* @actor_cmd
  %r138 = load i64, i64* %ptr_i
  %r139 = call i64 @_get(i64 %r137, i64 %r138)
  store i64 %r139, i64* %ptr_cmd
  %r140 = load i64, i64* @actor_text
  %r141 = load i64, i64* %ptr_i
  %r142 = call i64 @_get(i64 %r140, i64 %r141)
  %r143 = call i64 @signum_ex(i64 10)
  %r144 = call i64 @_add(i64 %r142, i64 %r143)
  %r145 = load i64, i64* %ptr_i
  %r146 = load i64, i64* @actor_text
  call i64 @_set(i64 %r146, i64 %r145, i64 %r144)
  %r147 = getelementptr [1 x i8], [1 x i8]* @.str.417, i64 0, i64 0
  %r148 = ptrtoint i8* %r147 to i64
  %r149 = load i64, i64* %ptr_i
  %r150 = load i64, i64* @actor_cmd
  call i64 @_set(i64 %r150, i64 %r149, i64 %r148)
  %r151 = getelementptr [1 x i8], [1 x i8]* @.str.418, i64 0, i64 0
  %r152 = ptrtoint i8* %r151 to i64
  store i64 %r152, i64* %ptr_out
  %r153 = load i64, i64* @actor_app
  %r154 = load i64, i64* %ptr_i
  %r155 = call i64 @_get(i64 %r153, i64 %r154)
  store i64 %r155, i64* %ptr_app_mode
  %r156 = getelementptr [1 x i8], [1 x i8]* @.str.419, i64 0, i64 0
  %r157 = ptrtoint i8* %r156 to i64
  store i64 %r157, i64* %ptr_prefix_run
  %r158 = load i64, i64* %ptr_cmd
  %r159 = call i64 @mensura(i64 %r158)
  %r161 = icmp sgt i64 %r159, 4
  %r160 = zext i1 %r161 to i64
  %r162 = icmp ne i64 %r160, 0
  br i1 %r162, label %L1365, label %L1367
L1365:
  %r163 = load i64, i64* %ptr_cmd
  %r164 = call i64 @pars(i64 %r163, i64 0, i64 4)
  store i64 %r164, i64* %ptr_prefix_run
  br label %L1367
L1367:
  %r165 = getelementptr [1 x i8], [1 x i8]* @.str.420, i64 0, i64 0
  %r166 = ptrtoint i8* %r165 to i64
  store i64 %r166, i64* %ptr_prefix_rev
  %r167 = load i64, i64* %ptr_cmd
  %r168 = call i64 @mensura(i64 %r167)
  %r170 = icmp sgt i64 %r168, 9
  %r169 = zext i1 %r170 to i64
  %r171 = icmp ne i64 %r169, 0
  br i1 %r171, label %L1368, label %L1370
L1368:
  %r172 = load i64, i64* %ptr_cmd
  %r173 = call i64 @pars(i64 %r172, i64 0, i64 9)
  store i64 %r173, i64* %ptr_prefix_rev
  br label %L1370
L1370:
  %r174 = getelementptr [1 x i8], [1 x i8]* @.str.421, i64 0, i64 0
  %r175 = ptrtoint i8* %r174 to i64
  store i64 %r175, i64* %ptr_prefix_read
  %r176 = load i64, i64* %ptr_cmd
  %r177 = call i64 @mensura(i64 %r176)
  %r179 = icmp sgt i64 %r177, 5
  %r178 = zext i1 %r179 to i64
  %r180 = icmp ne i64 %r178, 0
  br i1 %r180, label %L1371, label %L1373
L1371:
  %r181 = load i64, i64* %ptr_cmd
  %r182 = call i64 @pars(i64 %r181, i64 0, i64 5)
  store i64 %r182, i64* %ptr_prefix_read
  br label %L1373
L1373:
  %r183 = getelementptr [1 x i8], [1 x i8]* @.str.422, i64 0, i64 0
  %r184 = ptrtoint i8* %r183 to i64
  store i64 %r184, i64* %ptr_prefix_edit
  %r185 = load i64, i64* %ptr_cmd
  %r186 = call i64 @mensura(i64 %r185)
  %r188 = icmp sgt i64 %r186, 5
  %r187 = zext i1 %r188 to i64
  %r189 = icmp ne i64 %r187, 0
  br i1 %r189, label %L1374, label %L1376
L1374:
  %r190 = load i64, i64* %ptr_cmd
  %r191 = call i64 @pars(i64 %r190, i64 0, i64 5)
  store i64 %r191, i64* %ptr_prefix_edit
  br label %L1376
L1376:
  %r192 = load i64, i64* %ptr_app_mode
  %r193 = call i64 @_eq(i64 %r192, i64 0)
  %r194 = icmp ne i64 %r193, 0
  br i1 %r194, label %L1377, label %L1378
L1377:
  %r195 = load i64, i64* %ptr_cmd
  %r196 = getelementptr [5 x i8], [5 x i8]* @.str.423, i64 0, i64 0
  %r197 = ptrtoint i8* %r196 to i64
  %r198 = call i64 @_eq(i64 %r195, i64 %r197)
  %r199 = icmp ne i64 %r198, 0
  br i1 %r199, label %L1380, label %L1381
L1380:
  %r200 = getelementptr [6 x i8], [6 x i8]* @.str.424, i64 0, i64 0
  %r201 = ptrtoint i8* %r200 to i64
  store i64 %r201, i64* %ptr_out
  br label %L1382
L1381:
  %r202 = load i64, i64* %ptr_cmd
  %r203 = getelementptr [4 x i8], [4 x i8]* @.str.425, i64 0, i64 0
  %r204 = ptrtoint i8* %r203 to i64
  %r205 = call i64 @_eq(i64 %r202, i64 %r204)
  %r206 = icmp ne i64 %r205, 0
  br i1 %r206, label %L1383, label %L1384
L1383:
  store i64 0, i64* %ptr_n
  br label %L1386
L1386:
  %r207 = load i64, i64* %ptr_n
  %r208 = load i64, i64* @vfs_name
  %r209 = call i64 @mensura(i64 %r208)
  %r211 = icmp slt i64 %r207, %r209
  %r210 = zext i1 %r211 to i64
  %r212 = icmp ne i64 %r210, 0
  br i1 %r212, label %L1387, label %L1388
L1387:
  %r213 = load i64, i64* %ptr_out
  %r214 = load i64, i64* @vfs_name
  %r215 = load i64, i64* %ptr_n
  %r216 = call i64 @_get(i64 %r214, i64 %r215)
  %r217 = call i64 @_add(i64 %r213, i64 %r216)
  %r218 = getelementptr [3 x i8], [3 x i8]* @.str.426, i64 0, i64 0
  %r219 = ptrtoint i8* %r218 to i64
  %r220 = call i64 @_add(i64 %r217, i64 %r219)
  %r221 = load i64, i64* @vfs_size
  %r222 = load i64, i64* %ptr_n
  %r223 = call i64 @_get(i64 %r221, i64 %r222)
  %r224 = call i64 @int_to_str(i64 %r223)
  %r225 = call i64 @_add(i64 %r220, i64 %r224)
  %r226 = getelementptr [5 x i8], [5 x i8]* @.str.427, i64 0, i64 0
  %r227 = ptrtoint i8* %r226 to i64
  %r228 = call i64 @_add(i64 %r225, i64 %r227)
  store i64 %r228, i64* %ptr_out
  %r229 = load i64, i64* %ptr_n
  %r230 = call i64 @_add(i64 %r229, i64 1)
  store i64 %r230, i64* %ptr_n
  br label %L1386
L1388:
  br label %L1385
L1384:
  %r231 = load i64, i64* %ptr_prefix_read
  %r232 = getelementptr [6 x i8], [6 x i8]* @.str.428, i64 0, i64 0
  %r233 = ptrtoint i8* %r232 to i64
  %r234 = call i64 @_eq(i64 %r231, i64 %r233)
  %r235 = icmp ne i64 %r234, 0
  br i1 %r235, label %L1389, label %L1390
L1389:
  %r236 = load i64, i64* %ptr_cmd
  %r237 = load i64, i64* %ptr_cmd
  %r238 = call i64 @mensura(i64 %r237)
  %r239 = sub i64 %r238, 5
  %r240 = call i64 @pars(i64 %r236, i64 5, i64 %r239)
  store i64 %r240, i64* %ptr_fname
  %r241 = load i64, i64* %ptr_fname
  %r242 = call i64 @read_file(i64 %r241)
  %r243 = getelementptr [2 x i8], [2 x i8]* @.str.429, i64 0, i64 0
  %r244 = ptrtoint i8* %r243 to i64
  %r245 = call i64 @_add(i64 %r242, i64 %r244)
  store i64 %r245, i64* %ptr_out
  br label %L1391
L1390:
  %r246 = load i64, i64* %ptr_prefix_edit
  %r247 = getelementptr [6 x i8], [6 x i8]* @.str.430, i64 0, i64 0
  %r248 = ptrtoint i8* %r247 to i64
  %r249 = call i64 @_eq(i64 %r246, i64 %r248)
  %r250 = icmp ne i64 %r249, 0
  br i1 %r250, label %L1392, label %L1393
L1392:
  %r251 = load i64, i64* %ptr_cmd
  %r252 = load i64, i64* %ptr_cmd
  %r253 = call i64 @mensura(i64 %r252)
  %r254 = sub i64 %r253, 5
  %r255 = call i64 @pars(i64 %r251, i64 5, i64 %r254)
  store i64 %r255, i64* %ptr_fname
  %r256 = load i64, i64* %ptr_i
  %r257 = load i64, i64* @actor_app
  call i64 @_set(i64 %r257, i64 %r256, i64 2)
  %r258 = load i64, i64* %ptr_fname
  %r259 = load i64, i64* %ptr_i
  %r260 = load i64, i64* @actor_target
  call i64 @_set(i64 %r260, i64 %r259, i64 %r258)
  %r261 = load i64, i64* %ptr_fname
  %r262 = call i64 @file_exists(i64 %r261)
  %r263 = icmp ne i64 %r262, 0
  br i1 %r263, label %L1395, label %L1396
L1395:
  %r264 = load i64, i64* %ptr_fname
  %r265 = call i64 @read_file(i64 %r264)
  %r266 = load i64, i64* %ptr_i
  %r267 = load i64, i64* @actor_file_buf
  call i64 @_set(i64 %r267, i64 %r266, i64 %r265)
  br label %L1397
L1396:
  %r268 = getelementptr [1 x i8], [1 x i8]* @.str.431, i64 0, i64 0
  %r269 = ptrtoint i8* %r268 to i64
  %r270 = load i64, i64* %ptr_i
  %r271 = load i64, i64* @actor_file_buf
  call i64 @_set(i64 %r271, i64 %r270, i64 %r269)
  br label %L1397
L1397:
  %r272 = getelementptr [30 x i8], [30 x i8]* @.str.432, i64 0, i64 0
  %r273 = ptrtoint i8* %r272 to i64
  %r274 = load i64, i64* %ptr_fname
  %r275 = call i64 @_add(i64 %r273, i64 %r274)
  %r276 = getelementptr [47 x i8], [47 x i8]* @.str.433, i64 0, i64 0
  %r277 = ptrtoint i8* %r276 to i64
  %r278 = call i64 @_add(i64 %r275, i64 %r277)
  store i64 %r278, i64* %ptr_out
  br label %L1394
L1393:
  %r279 = load i64, i64* %ptr_prefix_run
  %r280 = getelementptr [5 x i8], [5 x i8]* @.str.434, i64 0, i64 0
  %r281 = ptrtoint i8* %r280 to i64
  %r282 = call i64 @_eq(i64 %r279, i64 %r281)
  %r283 = icmp ne i64 %r282, 0
  br i1 %r283, label %L1398, label %L1399
L1398:
  %r284 = load i64, i64* %ptr_cmd
  %r285 = load i64, i64* %ptr_cmd
  %r286 = call i64 @mensura(i64 %r285)
  %r287 = sub i64 %r286, 4
  %r288 = call i64 @pars(i64 %r284, i64 4, i64 %r287)
  store i64 %r288, i64* %ptr_target
  %r289 = load i64, i64* %ptr_target
  %r290 = getelementptr [8 x i8], [8 x i8]* @.str.435, i64 0, i64 0
  %r291 = ptrtoint i8* %r290 to i64
  %r292 = call i64 @_eq(i64 %r289, i64 %r291)
  %r293 = icmp ne i64 %r292, 0
  br i1 %r293, label %L1401, label %L1402
L1401:
  %r294 = load i64, i64* %ptr_i
  %r295 = load i64, i64* @actor_app
  call i64 @_set(i64 %r295, i64 %r294, i64 1)
  %r296 = getelementptr [26 x i8], [26 x i8]* @.str.436, i64 0, i64 0
  %r297 = ptrtoint i8* %r296 to i64
  store i64 %r297, i64* %ptr_out
  br label %L1403
L1402:
  %r298 = load i64, i64* %ptr_target
  %r299 = getelementptr [13 x i8], [13 x i8]* @.str.437, i64 0, i64 0
  %r300 = ptrtoint i8* %r299 to i64
  %r301 = call i64 @_eq(i64 %r298, i64 %r300)
  %r302 = icmp ne i64 %r301, 0
  br i1 %r302, label %L1404, label %L1405
L1404:
  %r303 = load i64, i64* %ptr_i
  %r304 = load i64, i64* @actor_app
  call i64 @_set(i64 %r304, i64 %r303, i64 2)
  %r305 = getelementptr [21 x i8], [21 x i8]* @.str.438, i64 0, i64 0
  %r306 = ptrtoint i8* %r305 to i64
  store i64 %r306, i64* %ptr_out
  br label %L1406
L1405:
  %r307 = load i64, i64* %ptr_target
  %r308 = call i64 @file_exists(i64 %r307)
  %r309 = icmp ne i64 %r308, 0
  br i1 %r309, label %L1407, label %L1408
L1407:
  %r310 = load i64, i64* %ptr_target
  %r311 = call i64 @read_file(i64 %r310)
  store i64 %r311, i64* %ptr_file_data
  %r312 = load i64, i64* %ptr_target
  %r313 = load i64, i64* %ptr_target
  %r314 = call i64 @mensura(i64 %r313)
  %r315 = sub i64 %r314, 4
  %r316 = call i64 @pars(i64 %r312, i64 %r315, i64 4)
  %r317 = getelementptr [5 x i8], [5 x i8]* @.str.439, i64 0, i64 0
  %r318 = ptrtoint i8* %r317 to i64
  %r319 = call i64 @_eq(i64 %r316, i64 %r318)
  %r320 = icmp ne i64 %r319, 0
  br i1 %r320, label %L1410, label %L1411
L1410:
  %r321 = load i64, i64* %ptr_i
  %r322 = load i64, i64* %ptr_file_data
  %r323 = call i64 @execute_achlys_script(i64 %r321, i64 %r322)
  br label %L1412
L1411:
  %r324 = getelementptr [33 x i8], [33 x i8]* @.str.440, i64 0, i64 0
  %r325 = ptrtoint i8* %r324 to i64
  store i64 %r325, i64* %ptr_out
  %r326 = load i64, i64* %ptr_i
  %r327 = load i64, i64* %ptr_file_data
  %r328 = call i64 @sys_exec(i64 %r326, i64 %r327)
  br label %L1412
L1412:
  br label %L1409
L1408:
  %r329 = getelementptr [35 x i8], [35 x i8]* @.str.441, i64 0, i64 0
  %r330 = ptrtoint i8* %r329 to i64
  %r331 = load i64, i64* %ptr_target
  %r332 = call i64 @_add(i64 %r330, i64 %r331)
  %r333 = getelementptr [2 x i8], [2 x i8]* @.str.442, i64 0, i64 0
  %r334 = ptrtoint i8* %r333 to i64
  %r335 = call i64 @_add(i64 %r332, i64 %r334)
  store i64 %r335, i64* %ptr_out
  br label %L1409
L1409:
  br label %L1406
L1406:
  br label %L1403
L1403:
  br label %L1400
L1399:
  %r336 = load i64, i64* %ptr_cmd
  %r337 = getelementptr [6 x i8], [6 x i8]* @.str.443, i64 0, i64 0
  %r338 = ptrtoint i8* %r337 to i64
  %r339 = call i64 @_eq(i64 %r336, i64 %r338)
  %r340 = icmp ne i64 %r339, 0
  br i1 %r340, label %L1413, label %L1414
L1413:
  %r341 = getelementptr [28 x i8], [28 x i8]* @.str.444, i64 0, i64 0
  %r342 = ptrtoint i8* %r341 to i64
  store i64 %r342, i64* %ptr_out
  store i64 0, i64* %ptr_bus
  br label %L1416
L1416:
  %r343 = load i64, i64* %ptr_bus
  %r345 = icmp slt i64 %r343, 256
  %r344 = zext i1 %r345 to i64
  %r346 = icmp ne i64 %r344, 0
  br i1 %r346, label %L1417, label %L1418
L1417:
  store i64 0, i64* %ptr_slot
  br label %L1419
L1419:
  %r347 = load i64, i64* %ptr_slot
  %r349 = icmp slt i64 %r347, 32
  %r348 = zext i1 %r349 to i64
  %r350 = icmp ne i64 %r348, 0
  br i1 %r350, label %L1420, label %L1421
L1420:
  %r351 = load i64, i64* %ptr_bus
  %r352 = load i64, i64* %ptr_slot
  %r353 = call i64 @pci_get_vendor(i64 %r351, i64 %r352)
  store i64 %r353, i64* %ptr_vendor
  %r354 = load i64, i64* %ptr_vendor
  %r356 = call i64 @_eq(i64 %r354, i64 65535)
  %r355 = xor i64 %r356, 1
  %r357 = icmp ne i64 %r355, 0
  br i1 %r357, label %L1422, label %L1424
L1422:
  %r358 = load i64, i64* %ptr_bus
  %r359 = load i64, i64* %ptr_slot
  %r360 = call i64 @pci_get_device(i64 %r358, i64 %r359)
  store i64 %r360, i64* %ptr_device
  %r361 = load i64, i64* %ptr_out
  %r362 = getelementptr [5 x i8], [5 x i8]* @.str.445, i64 0, i64 0
  %r363 = ptrtoint i8* %r362 to i64
  %r364 = call i64 @_add(i64 %r361, i64 %r363)
  %r365 = load i64, i64* %ptr_bus
  %r366 = call i64 @int_to_str(i64 %r365)
  %r367 = call i64 @_add(i64 %r364, i64 %r366)
  %r368 = getelementptr [7 x i8], [7 x i8]* @.str.446, i64 0, i64 0
  %r369 = ptrtoint i8* %r368 to i64
  %r370 = call i64 @_add(i64 %r367, i64 %r369)
  %r371 = load i64, i64* %ptr_slot
  %r372 = call i64 @int_to_str(i64 %r371)
  %r373 = call i64 @_add(i64 %r370, i64 %r372)
  %r374 = getelementptr [13 x i8], [13 x i8]* @.str.447, i64 0, i64 0
  %r375 = ptrtoint i8* %r374 to i64
  %r376 = call i64 @_add(i64 %r373, i64 %r375)
  %r377 = load i64, i64* %ptr_vendor
  %r378 = call i64 @int_to_str(i64 %r377)
  %r379 = call i64 @_add(i64 %r376, i64 %r378)
  %r380 = getelementptr [12 x i8], [12 x i8]* @.str.448, i64 0, i64 0
  %r381 = ptrtoint i8* %r380 to i64
  %r382 = call i64 @_add(i64 %r379, i64 %r381)
  %r383 = load i64, i64* %ptr_device
  %r384 = call i64 @int_to_str(i64 %r383)
  %r385 = call i64 @_add(i64 %r382, i64 %r384)
  %r386 = getelementptr [2 x i8], [2 x i8]* @.str.449, i64 0, i64 0
  %r387 = ptrtoint i8* %r386 to i64
  %r388 = call i64 @_add(i64 %r385, i64 %r387)
  store i64 %r388, i64* %ptr_out
  %r389 = load i64, i64* %ptr_vendor
  %r390 = call i64 @_eq(i64 %r389, i64 32902)
  store i64 0, i64* @.sc.450
  %r392 = icmp ne i64 %r390, 0
  br i1 %r392, label %L1425, label %L1426
L1425:
  %r393 = load i64, i64* %ptr_device
  %r394 = call i64 @_eq(i64 %r393, i64 4110)
  %r395 = icmp ne i64 %r394, 0
  %r396 = zext i1 %r395 to i64
  store i64 %r396, i64* @.sc.450
  br label %L1426
L1426:
  %r391 = load i64, i64* @.sc.450
  %r397 = icmp ne i64 %r391, 0
  br i1 %r397, label %L1427, label %L1429
L1427:
  %r398 = load i64, i64* %ptr_bus
  %r399 = load i64, i64* %ptr_slot
  %r400 = call i64 @init_e1000(i64 %r398, i64 %r399)
  store i64 %r400, i64* %ptr_mmio
  %r401 = call i64 @init_e1000_tx()
  %r402 = call i64 @init_e1000_rx()
  %r403 = load i64, i64* %ptr_out
  %r404 = getelementptr [37 x i8], [37 x i8]* @.str.451, i64 0, i64 0
  %r405 = ptrtoint i8* %r404 to i64
  %r406 = call i64 @_add(i64 %r403, i64 %r405)
  %r407 = load i64, i64* %ptr_mmio
  %r408 = call i64 @int_to_str(i64 %r407)
  %r409 = call i64 @_add(i64 %r406, i64 %r408)
  %r410 = getelementptr [2 x i8], [2 x i8]* @.str.452, i64 0, i64 0
  %r411 = ptrtoint i8* %r410 to i64
  %r412 = call i64 @_add(i64 %r409, i64 %r411)
  store i64 %r412, i64* %ptr_out
  %r413 = load i64, i64* %ptr_out
  %r414 = getelementptr [26 x i8], [26 x i8]* @.str.453, i64 0, i64 0
  %r415 = ptrtoint i8* %r414 to i64
  %r416 = call i64 @_add(i64 %r413, i64 %r415)
  %r417 = call i64 @get_mac_address()
  %r418 = call i64 @_add(i64 %r416, i64 %r417)
  %r419 = getelementptr [2 x i8], [2 x i8]* @.str.454, i64 0, i64 0
  %r420 = ptrtoint i8* %r419 to i64
  %r421 = call i64 @_add(i64 %r418, i64 %r420)
  store i64 %r421, i64* %ptr_out
  %r422 = load i64, i64* %ptr_out
  %r423 = getelementptr [43 x i8], [43 x i8]* @.str.455, i64 0, i64 0
  %r424 = ptrtoint i8* %r423 to i64
  %r425 = call i64 @_add(i64 %r422, i64 %r424)
  store i64 %r425, i64* %ptr_out
  br label %L1429
L1429:
  br label %L1424
L1424:
  %r426 = load i64, i64* %ptr_slot
  %r427 = call i64 @_add(i64 %r426, i64 1)
  store i64 %r427, i64* %ptr_slot
  br label %L1419
L1421:
  %r428 = load i64, i64* %ptr_bus
  %r429 = call i64 @_add(i64 %r428, i64 1)
  store i64 %r429, i64* %ptr_bus
  br label %L1416
L1418:
  br label %L1415
L1414:
  %r430 = load i64, i64* %ptr_cmd
  %r431 = getelementptr [8 x i8], [8 x i8]* @.str.456, i64 0, i64 0
  %r432 = ptrtoint i8* %r431 to i64
  %r433 = call i64 @_eq(i64 %r430, i64 %r432)
  %r434 = icmp ne i64 %r433, 0
  br i1 %r434, label %L1430, label %L1431
L1430:
  %r435 = load i64, i64* @E1000_BAR
  %r436 = call i64 @_eq(i64 %r435, i64 0)
  %r437 = icmp ne i64 %r436, 0
  br i1 %r437, label %L1433, label %L1434
L1433:
  %r438 = getelementptr [37 x i8], [37 x i8]* @.str.457, i64 0, i64 0
  %r439 = ptrtoint i8* %r438 to i64
  store i64 %r439, i64* %ptr_out
  br label %L1435
L1434:
  %r440 = call i64 @malloc(i64 64)
  store i64 %r440, i64* %ptr_frame
  %r441 = load i64, i64* %ptr_frame
  %r442 = call i64 @fast_fill32(i64 %r441, i64 0, i64 16)
  %r443 = load i64, i64* %ptr_frame
  %r444 = add i64 %r443, 0
  %r445 = inttoptr i64 %r444 to ptr
  %r446 = trunc i64 255 to i8
  store volatile i8 %r446, ptr %r445
  %r447 = load i64, i64* %ptr_frame
  %r448 = add i64 %r447, 1
  %r449 = inttoptr i64 %r448 to ptr
  %r450 = trunc i64 255 to i8
  store volatile i8 %r450, ptr %r449
  %r451 = load i64, i64* %ptr_frame
  %r452 = add i64 %r451, 2
  %r453 = inttoptr i64 %r452 to ptr
  %r454 = trunc i64 255 to i8
  store volatile i8 %r454, ptr %r453
  %r455 = load i64, i64* %ptr_frame
  %r456 = add i64 %r455, 3
  %r457 = inttoptr i64 %r456 to ptr
  %r458 = trunc i64 255 to i8
  store volatile i8 %r458, ptr %r457
  %r459 = load i64, i64* %ptr_frame
  %r460 = add i64 %r459, 4
  %r461 = inttoptr i64 %r460 to ptr
  %r462 = trunc i64 255 to i8
  store volatile i8 %r462, ptr %r461
  %r463 = load i64, i64* %ptr_frame
  %r464 = add i64 %r463, 5
  %r465 = inttoptr i64 %r464 to ptr
  %r466 = trunc i64 255 to i8
  store volatile i8 %r466, ptr %r465
  %r467 = load i64, i64* %ptr_frame
  %r468 = add i64 %r467, 6
  %r469 = inttoptr i64 %r468 to ptr
  %r470 = trunc i64 82 to i8
  store volatile i8 %r470, ptr %r469
  %r471 = load i64, i64* %ptr_frame
  %r472 = add i64 %r471, 7
  %r473 = inttoptr i64 %r472 to ptr
  %r474 = trunc i64 84 to i8
  store volatile i8 %r474, ptr %r473
  %r475 = load i64, i64* %ptr_frame
  %r476 = add i64 %r475, 8
  %r477 = inttoptr i64 %r476 to ptr
  %r478 = trunc i64 0 to i8
  store volatile i8 %r478, ptr %r477
  %r479 = load i64, i64* %ptr_frame
  %r480 = add i64 %r479, 9
  %r481 = inttoptr i64 %r480 to ptr
  %r482 = trunc i64 18 to i8
  store volatile i8 %r482, ptr %r481
  %r483 = load i64, i64* %ptr_frame
  %r484 = add i64 %r483, 10
  %r485 = inttoptr i64 %r484 to ptr
  %r486 = trunc i64 52 to i8
  store volatile i8 %r486, ptr %r485
  %r487 = load i64, i64* %ptr_frame
  %r488 = add i64 %r487, 11
  %r489 = inttoptr i64 %r488 to ptr
  %r490 = trunc i64 86 to i8
  store volatile i8 %r490, ptr %r489
  %r491 = load i64, i64* %ptr_frame
  %r492 = add i64 %r491, 12
  %r493 = inttoptr i64 %r492 to ptr
  %r494 = trunc i64 8 to i8
  store volatile i8 %r494, ptr %r493
  %r495 = load i64, i64* %ptr_frame
  %r496 = add i64 %r495, 13
  %r497 = inttoptr i64 %r496 to ptr
  %r498 = trunc i64 6 to i8
  store volatile i8 %r498, ptr %r497
  %r499 = load i64, i64* %ptr_frame
  %r500 = add i64 %r499, 14
  store i64 %r500, i64* %ptr_arp
  %r501 = load i64, i64* %ptr_arp
  %r502 = add i64 %r501, 0
  %r503 = inttoptr i64 %r502 to ptr
  %r504 = trunc i64 0 to i8
  store volatile i8 %r504, ptr %r503
  %r505 = load i64, i64* %ptr_arp
  %r506 = add i64 %r505, 1
  %r507 = inttoptr i64 %r506 to ptr
  %r508 = trunc i64 1 to i8
  store volatile i8 %r508, ptr %r507
  %r509 = load i64, i64* %ptr_arp
  %r510 = add i64 %r509, 2
  %r511 = inttoptr i64 %r510 to ptr
  %r512 = trunc i64 8 to i8
  store volatile i8 %r512, ptr %r511
  %r513 = load i64, i64* %ptr_arp
  %r514 = add i64 %r513, 3
  %r515 = inttoptr i64 %r514 to ptr
  %r516 = trunc i64 0 to i8
  store volatile i8 %r516, ptr %r515
  %r517 = load i64, i64* %ptr_arp
  %r518 = add i64 %r517, 4
  %r519 = inttoptr i64 %r518 to ptr
  %r520 = trunc i64 6 to i8
  store volatile i8 %r520, ptr %r519
  %r521 = load i64, i64* %ptr_arp
  %r522 = add i64 %r521, 5
  %r523 = inttoptr i64 %r522 to ptr
  %r524 = trunc i64 4 to i8
  store volatile i8 %r524, ptr %r523
  %r525 = load i64, i64* %ptr_arp
  %r526 = add i64 %r525, 6
  %r527 = inttoptr i64 %r526 to ptr
  %r528 = trunc i64 0 to i8
  store volatile i8 %r528, ptr %r527
  %r529 = load i64, i64* %ptr_arp
  %r530 = add i64 %r529, 7
  %r531 = inttoptr i64 %r530 to ptr
  %r532 = trunc i64 1 to i8
  store volatile i8 %r532, ptr %r531
  %r533 = load i64, i64* %ptr_arp
  %r534 = add i64 %r533, 8
  %r535 = inttoptr i64 %r534 to ptr
  %r536 = trunc i64 82 to i8
  store volatile i8 %r536, ptr %r535
  %r537 = load i64, i64* %ptr_arp
  %r538 = add i64 %r537, 9
  %r539 = inttoptr i64 %r538 to ptr
  %r540 = trunc i64 84 to i8
  store volatile i8 %r540, ptr %r539
  %r541 = load i64, i64* %ptr_arp
  %r542 = add i64 %r541, 10
  %r543 = inttoptr i64 %r542 to ptr
  %r544 = trunc i64 0 to i8
  store volatile i8 %r544, ptr %r543
  %r545 = load i64, i64* %ptr_arp
  %r546 = add i64 %r545, 11
  %r547 = inttoptr i64 %r546 to ptr
  %r548 = trunc i64 18 to i8
  store volatile i8 %r548, ptr %r547
  %r549 = load i64, i64* %ptr_arp
  %r550 = add i64 %r549, 12
  %r551 = inttoptr i64 %r550 to ptr
  %r552 = trunc i64 52 to i8
  store volatile i8 %r552, ptr %r551
  %r553 = load i64, i64* %ptr_arp
  %r554 = add i64 %r553, 13
  %r555 = inttoptr i64 %r554 to ptr
  %r556 = trunc i64 86 to i8
  store volatile i8 %r556, ptr %r555
  %r557 = load i64, i64* %ptr_arp
  %r558 = add i64 %r557, 14
  %r559 = inttoptr i64 %r558 to ptr
  %r560 = trunc i64 10 to i8
  store volatile i8 %r560, ptr %r559
  %r561 = load i64, i64* %ptr_arp
  %r562 = add i64 %r561, 15
  %r563 = inttoptr i64 %r562 to ptr
  %r564 = trunc i64 0 to i8
  store volatile i8 %r564, ptr %r563
  %r565 = load i64, i64* %ptr_arp
  %r566 = add i64 %r565, 16
  %r567 = inttoptr i64 %r566 to ptr
  %r568 = trunc i64 2 to i8
  store volatile i8 %r568, ptr %r567
  %r569 = load i64, i64* %ptr_arp
  %r570 = add i64 %r569, 17
  %r571 = inttoptr i64 %r570 to ptr
  %r572 = trunc i64 15 to i8
  store volatile i8 %r572, ptr %r571
  %r573 = load i64, i64* %ptr_arp
  %r574 = add i64 %r573, 24
  %r575 = inttoptr i64 %r574 to ptr
  %r576 = trunc i64 10 to i8
  store volatile i8 %r576, ptr %r575
  %r577 = load i64, i64* %ptr_arp
  %r578 = add i64 %r577, 25
  %r579 = inttoptr i64 %r578 to ptr
  %r580 = trunc i64 0 to i8
  store volatile i8 %r580, ptr %r579
  %r581 = load i64, i64* %ptr_arp
  %r582 = add i64 %r581, 26
  %r583 = inttoptr i64 %r582 to ptr
  %r584 = trunc i64 2 to i8
  store volatile i8 %r584, ptr %r583
  %r585 = load i64, i64* %ptr_arp
  %r586 = add i64 %r585, 27
  %r587 = inttoptr i64 %r586 to ptr
  %r588 = trunc i64 2 to i8
  store volatile i8 %r588, ptr %r587
  %r589 = getelementptr [44 x i8], [44 x i8]* @.str.458, i64 0, i64 0
  %r590 = ptrtoint i8* %r589 to i64
  store i64 %r590, i64* %ptr_out
  %r591 = load i64, i64* %ptr_frame
  %r592 = call i64 @e1000_transmit(i64 %r591, i64 64)
  store i64 %r592, i64* %ptr_status_ptr
  store i64 100000, i64* %ptr_timeout
  store i64 0, i64* %ptr_done
  br label %L1436
L1436:
  %r593 = load i64, i64* %ptr_timeout
  %r595 = icmp sgt i64 %r593, 0
  %r594 = zext i1 %r595 to i64
  store i64 0, i64* @.sc.459
  %r597 = icmp ne i64 %r594, 0
  br i1 %r597, label %L1439, label %L1440
L1439:
  %r598 = load i64, i64* %ptr_done
  %r599 = call i64 @_eq(i64 %r598, i64 0)
  %r600 = icmp ne i64 %r599, 0
  %r601 = zext i1 %r600 to i64
  store i64 %r601, i64* @.sc.459
  br label %L1440
L1440:
  %r596 = load i64, i64* @.sc.459
  %r602 = icmp ne i64 %r596, 0
  br i1 %r602, label %L1437, label %L1438
L1437:
  %r603 = load i64, i64* @E1000_BAR
  %r604 = add i64 %r603, 14352
  %r605 = inttoptr i64 %r604 to i32*
  %r606 = load volatile i32, i32* %r605
  %r607 = zext i32 %r606 to i64
  store i64 %r607, i64* %ptr_head
  %r608 = load i64, i64* %ptr_head
  %r609 = load i64, i64* @E1000_TX_TAIL
  %r610 = call i64 @_eq(i64 %r608, i64 %r609)
  %r611 = icmp ne i64 %r610, 0
  br i1 %r611, label %L1441, label %L1443
L1441:
  store i64 1, i64* %ptr_done
  br label %L1443
L1443:
  %r612 = load i64, i64* %ptr_timeout
  %r613 = sub i64 %r612, 1
  store i64 %r613, i64* %ptr_timeout
  br label %L1436
L1438:
  %r614 = load i64, i64* %ptr_done
  %r615 = icmp ne i64 %r614, 0
  br i1 %r615, label %L1444, label %L1445
L1444:
  %r616 = load i64, i64* %ptr_out
  %r617 = getelementptr [46 x i8], [46 x i8]* @.str.460, i64 0, i64 0
  %r618 = ptrtoint i8* %r617 to i64
  %r619 = call i64 @_add(i64 %r616, i64 %r618)
  store i64 %r619, i64* %ptr_out
  br label %L1446
L1445:
  %r620 = load i64, i64* %ptr_out
  %r621 = getelementptr [39 x i8], [39 x i8]* @.str.461, i64 0, i64 0
  %r622 = ptrtoint i8* %r621 to i64
  %r623 = call i64 @_add(i64 %r620, i64 %r622)
  store i64 %r623, i64* %ptr_out
  br label %L1446
L1446:
  br label %L1435
L1435:
  br label %L1432
L1431:
  %r624 = load i64, i64* %ptr_cmd
  %r625 = getelementptr [8 x i8], [8 x i8]* @.str.462, i64 0, i64 0
  %r626 = ptrtoint i8* %r625 to i64
  %r627 = call i64 @_eq(i64 %r624, i64 %r626)
  %r628 = icmp ne i64 %r627, 0
  br i1 %r628, label %L1447, label %L1448
L1447:
  %r629 = load i64, i64* @E1000_BAR
  %r630 = call i64 @_eq(i64 %r629, i64 0)
  %r631 = icmp ne i64 %r630, 0
  br i1 %r631, label %L1450, label %L1451
L1450:
  %r632 = getelementptr [37 x i8], [37 x i8]* @.str.463, i64 0, i64 0
  %r633 = ptrtoint i8* %r632 to i64
  store i64 %r633, i64* %ptr_out
  br label %L1452
L1451:
  %r634 = call i64 @e1000_poll_rx()
  store i64 %r634, i64* %ptr_pkt
  %r635 = load i64, i64* %ptr_pkt
  %r637 = call i64 @_eq(i64 %r635, i64 0)
  %r636 = xor i64 %r637, 1
  %r638 = icmp ne i64 %r636, 0
  br i1 %r638, label %L1453, label %L1454
L1453:
  %r639 = getelementptr [33 x i8], [33 x i8]* @.str.464, i64 0, i64 0
  %r640 = ptrtoint i8* %r639 to i64
  %r641 = load i64, i64* @E1000_RX_LEN
  %r642 = call i64 @int_to_str(i64 %r641)
  %r643 = call i64 @_add(i64 %r640, i64 %r642)
  %r644 = getelementptr [8 x i8], [8 x i8]* @.str.465, i64 0, i64 0
  %r645 = ptrtoint i8* %r644 to i64
  %r646 = call i64 @_add(i64 %r643, i64 %r645)
  store i64 %r646, i64* %ptr_out
  %r647 = load i64, i64* %ptr_out
  %r648 = getelementptr [33 x i8], [33 x i8]* @.str.466, i64 0, i64 0
  %r649 = ptrtoint i8* %r648 to i64
  %r650 = call i64 @_add(i64 %r647, i64 %r649)
  store i64 %r650, i64* %ptr_out
  store i64 0, i64* %ptr_j
  %r651 = getelementptr [1 x i8], [1 x i8]* @.str.467, i64 0, i64 0
  %r652 = ptrtoint i8* %r651 to i64
  store i64 %r652, i64* %ptr_dump
  br label %L1456
L1456:
  %r653 = load i64, i64* %ptr_j
  %r654 = load i64, i64* @E1000_RX_LEN
  %r656 = icmp slt i64 %r653, %r654
  %r655 = zext i1 %r656 to i64
  store i64 0, i64* @.sc.468
  %r658 = icmp ne i64 %r655, 0
  br i1 %r658, label %L1459, label %L1460
L1459:
  %r659 = load i64, i64* %ptr_j
  %r661 = icmp slt i64 %r659, 42
  %r660 = zext i1 %r661 to i64
  %r662 = icmp ne i64 %r660, 0
  %r663 = zext i1 %r662 to i64
  store i64 %r663, i64* @.sc.468
  br label %L1460
L1460:
  %r657 = load i64, i64* @.sc.468
  %r664 = icmp ne i64 %r657, 0
  br i1 %r664, label %L1457, label %L1458
L1457:
  %r665 = load i64, i64* %ptr_pkt
  %r666 = load i64, i64* %ptr_j
  %r667 = add i64 %r665, %r666
  %r668 = inttoptr i64 %r667 to ptr
  %r669 = load volatile i8, ptr %r668
  %r670 = zext i8 %r669 to i64
  store i64 %r670, i64* %ptr_b
  %r671 = load i64, i64* %ptr_dump
  %r672 = load i64, i64* %ptr_b
  %r673 = call i64 @int_to_str(i64 %r672)
  %r674 = call i64 @_add(i64 %r671, i64 %r673)
  %r675 = getelementptr [2 x i8], [2 x i8]* @.str.469, i64 0, i64 0
  %r676 = ptrtoint i8* %r675 to i64
  %r677 = call i64 @_add(i64 %r674, i64 %r676)
  store i64 %r677, i64* %ptr_dump
  %r678 = load i64, i64* %ptr_j
  %r679 = call i64 @_add(i64 %r678, i64 1)
  store i64 %r679, i64* %ptr_j
  br label %L1456
L1458:
  %r680 = load i64, i64* %ptr_out
  %r681 = load i64, i64* %ptr_dump
  %r682 = call i64 @_add(i64 %r680, i64 %r681)
  %r683 = getelementptr [2 x i8], [2 x i8]* @.str.470, i64 0, i64 0
  %r684 = ptrtoint i8* %r683 to i64
  %r685 = call i64 @_add(i64 %r682, i64 %r684)
  store i64 %r685, i64* %ptr_out
  br label %L1455
L1454:
  %r686 = getelementptr [40 x i8], [40 x i8]* @.str.471, i64 0, i64 0
  %r687 = ptrtoint i8* %r686 to i64
  store i64 %r687, i64* %ptr_out
  br label %L1455
L1455:
  br label %L1452
L1452:
  br label %L1449
L1448:
  %r688 = load i64, i64* %ptr_cmd
  %r689 = getelementptr [9 x i8], [9 x i8]* @.str.472, i64 0, i64 0
  %r690 = ptrtoint i8* %r689 to i64
  %r691 = call i64 @_eq(i64 %r688, i64 %r690)
  %r692 = icmp ne i64 %r691, 0
  br i1 %r692, label %L1461, label %L1462
L1461:
  %r693 = load i64, i64* @E1000_BAR
  %r694 = call i64 @_eq(i64 %r693, i64 0)
  %r695 = icmp ne i64 %r694, 0
  br i1 %r695, label %L1464, label %L1465
L1464:
  %r696 = getelementptr [37 x i8], [37 x i8]* @.str.473, i64 0, i64 0
  %r697 = ptrtoint i8* %r696 to i64
  store i64 %r697, i64* %ptr_out
  br label %L1466
L1465:
  %r698 = call i64 @malloc(i64 128)
  store i64 %r698, i64* %ptr_frame
  store i64 0, i64* %ptr_z
  br label %L1467
L1467:
  %r699 = load i64, i64* %ptr_z
  %r701 = icmp slt i64 %r699, 128
  %r700 = zext i1 %r701 to i64
  %r702 = icmp ne i64 %r700, 0
  br i1 %r702, label %L1468, label %L1469
L1468:
  %r703 = load i64, i64* %ptr_frame
  %r704 = load i64, i64* %ptr_z
  %r705 = add i64 %r703, %r704
  %r706 = inttoptr i64 %r705 to ptr
  %r707 = trunc i64 0 to i8
  store volatile i8 %r707, ptr %r706
  %r708 = load i64, i64* %ptr_z
  %r709 = call i64 @_add(i64 %r708, i64 1)
  store i64 %r709, i64* %ptr_z
  br label %L1467
L1469:
  %r710 = load i64, i64* %ptr_frame
  %r711 = add i64 %r710, 0
  %r712 = inttoptr i64 %r711 to ptr
  %r713 = trunc i64 82 to i8
  store volatile i8 %r713, ptr %r712
  %r714 = load i64, i64* %ptr_frame
  %r715 = add i64 %r714, 1
  %r716 = inttoptr i64 %r715 to ptr
  %r717 = trunc i64 85 to i8
  store volatile i8 %r717, ptr %r716
  %r718 = load i64, i64* %ptr_frame
  %r719 = add i64 %r718, 2
  %r720 = inttoptr i64 %r719 to ptr
  %r721 = trunc i64 10 to i8
  store volatile i8 %r721, ptr %r720
  %r722 = load i64, i64* %ptr_frame
  %r723 = add i64 %r722, 3
  %r724 = inttoptr i64 %r723 to ptr
  %r725 = trunc i64 0 to i8
  store volatile i8 %r725, ptr %r724
  %r726 = load i64, i64* %ptr_frame
  %r727 = add i64 %r726, 4
  %r728 = inttoptr i64 %r727 to ptr
  %r729 = trunc i64 2 to i8
  store volatile i8 %r729, ptr %r728
  %r730 = load i64, i64* %ptr_frame
  %r731 = add i64 %r730, 5
  %r732 = inttoptr i64 %r731 to ptr
  %r733 = trunc i64 3 to i8
  store volatile i8 %r733, ptr %r732
  %r734 = load i64, i64* %ptr_frame
  %r735 = add i64 %r734, 6
  %r736 = inttoptr i64 %r735 to ptr
  %r737 = trunc i64 82 to i8
  store volatile i8 %r737, ptr %r736
  %r738 = load i64, i64* %ptr_frame
  %r739 = add i64 %r738, 7
  %r740 = inttoptr i64 %r739 to ptr
  %r741 = trunc i64 84 to i8
  store volatile i8 %r741, ptr %r740
  %r742 = load i64, i64* %ptr_frame
  %r743 = add i64 %r742, 8
  %r744 = inttoptr i64 %r743 to ptr
  %r745 = trunc i64 0 to i8
  store volatile i8 %r745, ptr %r744
  %r746 = load i64, i64* %ptr_frame
  %r747 = add i64 %r746, 9
  %r748 = inttoptr i64 %r747 to ptr
  %r749 = trunc i64 18 to i8
  store volatile i8 %r749, ptr %r748
  %r750 = load i64, i64* %ptr_frame
  %r751 = add i64 %r750, 10
  %r752 = inttoptr i64 %r751 to ptr
  %r753 = trunc i64 52 to i8
  store volatile i8 %r753, ptr %r752
  %r754 = load i64, i64* %ptr_frame
  %r755 = add i64 %r754, 11
  %r756 = inttoptr i64 %r755 to ptr
  %r757 = trunc i64 86 to i8
  store volatile i8 %r757, ptr %r756
  %r758 = load i64, i64* %ptr_frame
  %r759 = add i64 %r758, 12
  %r760 = inttoptr i64 %r759 to ptr
  %r761 = trunc i64 8 to i8
  store volatile i8 %r761, ptr %r760
  %r762 = load i64, i64* %ptr_frame
  %r763 = add i64 %r762, 13
  %r764 = inttoptr i64 %r763 to ptr
  %r765 = trunc i64 0 to i8
  store volatile i8 %r765, ptr %r764
  %r766 = load i64, i64* %ptr_frame
  %r767 = add i64 %r766, 14
  store i64 %r767, i64* %ptr_ip
  %r768 = load i64, i64* %ptr_ip
  %r769 = add i64 %r768, 0
  %r770 = inttoptr i64 %r769 to ptr
  %r771 = trunc i64 69 to i8
  store volatile i8 %r771, ptr %r770
  %r772 = load i64, i64* %ptr_ip
  %r773 = add i64 %r772, 1
  %r774 = inttoptr i64 %r773 to ptr
  %r775 = trunc i64 0 to i8
  store volatile i8 %r775, ptr %r774
  %r776 = load i64, i64* %ptr_ip
  %r777 = add i64 %r776, 2
  %r778 = inttoptr i64 %r777 to ptr
  %r779 = trunc i64 0 to i8
  store volatile i8 %r779, ptr %r778
  %r780 = load i64, i64* %ptr_ip
  %r781 = add i64 %r780, 3
  %r782 = inttoptr i64 %r781 to ptr
  %r783 = trunc i64 56 to i8
  store volatile i8 %r783, ptr %r782
  %r784 = load i64, i64* %ptr_ip
  %r785 = add i64 %r784, 4
  %r786 = inttoptr i64 %r785 to ptr
  %r787 = trunc i64 18 to i8
  store volatile i8 %r787, ptr %r786
  %r788 = load i64, i64* %ptr_ip
  %r789 = add i64 %r788, 5
  %r790 = inttoptr i64 %r789 to ptr
  %r791 = trunc i64 52 to i8
  store volatile i8 %r791, ptr %r790
  %r792 = load i64, i64* %ptr_ip
  %r793 = add i64 %r792, 6
  %r794 = inttoptr i64 %r793 to ptr
  %r795 = trunc i64 0 to i8
  store volatile i8 %r795, ptr %r794
  %r796 = load i64, i64* %ptr_ip
  %r797 = add i64 %r796, 7
  %r798 = inttoptr i64 %r797 to ptr
  %r799 = trunc i64 0 to i8
  store volatile i8 %r799, ptr %r798
  %r800 = load i64, i64* %ptr_ip
  %r801 = add i64 %r800, 8
  %r802 = inttoptr i64 %r801 to ptr
  %r803 = trunc i64 64 to i8
  store volatile i8 %r803, ptr %r802
  %r804 = load i64, i64* %ptr_ip
  %r805 = add i64 %r804, 9
  %r806 = inttoptr i64 %r805 to ptr
  %r807 = trunc i64 17 to i8
  store volatile i8 %r807, ptr %r806
  %r808 = load i64, i64* %ptr_ip
  %r809 = add i64 %r808, 10
  %r810 = inttoptr i64 %r809 to ptr
  %r811 = trunc i64 80 to i8
  store volatile i8 %r811, ptr %r810
  %r812 = load i64, i64* %ptr_ip
  %r813 = add i64 %r812, 11
  %r814 = inttoptr i64 %r813 to ptr
  %r815 = trunc i64 112 to i8
  store volatile i8 %r815, ptr %r814
  %r816 = load i64, i64* %ptr_ip
  %r817 = add i64 %r816, 12
  %r818 = inttoptr i64 %r817 to ptr
  %r819 = trunc i64 10 to i8
  store volatile i8 %r819, ptr %r818
  %r820 = load i64, i64* %ptr_ip
  %r821 = add i64 %r820, 13
  %r822 = inttoptr i64 %r821 to ptr
  %r823 = trunc i64 0 to i8
  store volatile i8 %r823, ptr %r822
  %r824 = load i64, i64* %ptr_ip
  %r825 = add i64 %r824, 14
  %r826 = inttoptr i64 %r825 to ptr
  %r827 = trunc i64 2 to i8
  store volatile i8 %r827, ptr %r826
  %r828 = load i64, i64* %ptr_ip
  %r829 = add i64 %r828, 15
  %r830 = inttoptr i64 %r829 to ptr
  %r831 = trunc i64 15 to i8
  store volatile i8 %r831, ptr %r830
  %r832 = load i64, i64* %ptr_ip
  %r833 = add i64 %r832, 16
  %r834 = inttoptr i64 %r833 to ptr
  %r835 = trunc i64 10 to i8
  store volatile i8 %r835, ptr %r834
  %r836 = load i64, i64* %ptr_ip
  %r837 = add i64 %r836, 17
  %r838 = inttoptr i64 %r837 to ptr
  %r839 = trunc i64 0 to i8
  store volatile i8 %r839, ptr %r838
  %r840 = load i64, i64* %ptr_ip
  %r841 = add i64 %r840, 18
  %r842 = inttoptr i64 %r841 to ptr
  %r843 = trunc i64 2 to i8
  store volatile i8 %r843, ptr %r842
  %r844 = load i64, i64* %ptr_ip
  %r845 = add i64 %r844, 19
  %r846 = inttoptr i64 %r845 to ptr
  %r847 = trunc i64 3 to i8
  store volatile i8 %r847, ptr %r846
  %r848 = load i64, i64* %ptr_frame
  %r849 = add i64 %r848, 34
  store i64 %r849, i64* %ptr_udp
  %r850 = load i64, i64* %ptr_udp
  %r851 = add i64 %r850, 0
  %r852 = inttoptr i64 %r851 to ptr
  %r853 = trunc i64 192 to i8
  store volatile i8 %r853, ptr %r852
  %r854 = load i64, i64* %ptr_udp
  %r855 = add i64 %r854, 1
  %r856 = inttoptr i64 %r855 to ptr
  %r857 = trunc i64 0 to i8
  store volatile i8 %r857, ptr %r856
  %r858 = load i64, i64* %ptr_udp
  %r859 = add i64 %r858, 2
  %r860 = inttoptr i64 %r859 to ptr
  %r861 = trunc i64 0 to i8
  store volatile i8 %r861, ptr %r860
  %r862 = load i64, i64* %ptr_udp
  %r863 = add i64 %r862, 3
  %r864 = inttoptr i64 %r863 to ptr
  %r865 = trunc i64 53 to i8
  store volatile i8 %r865, ptr %r864
  %r866 = load i64, i64* %ptr_udp
  %r867 = add i64 %r866, 4
  %r868 = inttoptr i64 %r867 to ptr
  %r869 = trunc i64 0 to i8
  store volatile i8 %r869, ptr %r868
  %r870 = load i64, i64* %ptr_udp
  %r871 = add i64 %r870, 5
  %r872 = inttoptr i64 %r871 to ptr
  %r873 = trunc i64 36 to i8
  store volatile i8 %r873, ptr %r872
  %r874 = load i64, i64* %ptr_udp
  %r875 = add i64 %r874, 6
  %r876 = inttoptr i64 %r875 to ptr
  %r877 = trunc i64 0 to i8
  store volatile i8 %r877, ptr %r876
  %r878 = load i64, i64* %ptr_udp
  %r879 = add i64 %r878, 7
  %r880 = inttoptr i64 %r879 to ptr
  %r881 = trunc i64 0 to i8
  store volatile i8 %r881, ptr %r880
  %r882 = load i64, i64* %ptr_frame
  %r883 = add i64 %r882, 42
  store i64 %r883, i64* %ptr_dns
  %r884 = load i64, i64* %ptr_dns
  %r885 = add i64 %r884, 0
  %r886 = inttoptr i64 %r885 to ptr
  %r887 = trunc i64 18 to i8
  store volatile i8 %r887, ptr %r886
  %r888 = load i64, i64* %ptr_dns
  %r889 = add i64 %r888, 1
  %r890 = inttoptr i64 %r889 to ptr
  %r891 = trunc i64 52 to i8
  store volatile i8 %r891, ptr %r890
  %r892 = load i64, i64* %ptr_dns
  %r893 = add i64 %r892, 2
  %r894 = inttoptr i64 %r893 to ptr
  %r895 = trunc i64 1 to i8
  store volatile i8 %r895, ptr %r894
  %r896 = load i64, i64* %ptr_dns
  %r897 = add i64 %r896, 3
  %r898 = inttoptr i64 %r897 to ptr
  %r899 = trunc i64 0 to i8
  store volatile i8 %r899, ptr %r898
  %r900 = load i64, i64* %ptr_dns
  %r901 = add i64 %r900, 4
  %r902 = inttoptr i64 %r901 to ptr
  %r903 = trunc i64 0 to i8
  store volatile i8 %r903, ptr %r902
  %r904 = load i64, i64* %ptr_dns
  %r905 = add i64 %r904, 5
  %r906 = inttoptr i64 %r905 to ptr
  %r907 = trunc i64 1 to i8
  store volatile i8 %r907, ptr %r906
  %r908 = load i64, i64* %ptr_dns
  %r909 = add i64 %r908, 6
  %r910 = inttoptr i64 %r909 to ptr
  %r911 = trunc i64 0 to i8
  store volatile i8 %r911, ptr %r910
  %r912 = load i64, i64* %ptr_dns
  %r913 = add i64 %r912, 7
  %r914 = inttoptr i64 %r913 to ptr
  %r915 = trunc i64 0 to i8
  store volatile i8 %r915, ptr %r914
  %r916 = load i64, i64* %ptr_dns
  %r917 = add i64 %r916, 8
  %r918 = inttoptr i64 %r917 to ptr
  %r919 = trunc i64 0 to i8
  store volatile i8 %r919, ptr %r918
  %r920 = load i64, i64* %ptr_dns
  %r921 = add i64 %r920, 9
  %r922 = inttoptr i64 %r921 to ptr
  %r923 = trunc i64 0 to i8
  store volatile i8 %r923, ptr %r922
  %r924 = load i64, i64* %ptr_dns
  %r925 = add i64 %r924, 10
  %r926 = inttoptr i64 %r925 to ptr
  %r927 = trunc i64 0 to i8
  store volatile i8 %r927, ptr %r926
  %r928 = load i64, i64* %ptr_dns
  %r929 = add i64 %r928, 11
  %r930 = inttoptr i64 %r929 to ptr
  %r931 = trunc i64 0 to i8
  store volatile i8 %r931, ptr %r930
  %r932 = load i64, i64* %ptr_dns
  %r933 = add i64 %r932, 12
  %r934 = inttoptr i64 %r933 to ptr
  %r935 = trunc i64 6 to i8
  store volatile i8 %r935, ptr %r934
  %r936 = load i64, i64* %ptr_dns
  %r937 = add i64 %r936, 13
  %r938 = inttoptr i64 %r937 to ptr
  %r939 = trunc i64 103 to i8
  store volatile i8 %r939, ptr %r938
  %r940 = load i64, i64* %ptr_dns
  %r941 = add i64 %r940, 14
  %r942 = inttoptr i64 %r941 to ptr
  %r943 = trunc i64 111 to i8
  store volatile i8 %r943, ptr %r942
  %r944 = load i64, i64* %ptr_dns
  %r945 = add i64 %r944, 15
  %r946 = inttoptr i64 %r945 to ptr
  %r947 = trunc i64 111 to i8
  store volatile i8 %r947, ptr %r946
  %r948 = load i64, i64* %ptr_dns
  %r949 = add i64 %r948, 16
  %r950 = inttoptr i64 %r949 to ptr
  %r951 = trunc i64 103 to i8
  store volatile i8 %r951, ptr %r950
  %r952 = load i64, i64* %ptr_dns
  %r953 = add i64 %r952, 17
  %r954 = inttoptr i64 %r953 to ptr
  %r955 = trunc i64 108 to i8
  store volatile i8 %r955, ptr %r954
  %r956 = load i64, i64* %ptr_dns
  %r957 = add i64 %r956, 18
  %r958 = inttoptr i64 %r957 to ptr
  %r959 = trunc i64 101 to i8
  store volatile i8 %r959, ptr %r958
  %r960 = load i64, i64* %ptr_dns
  %r961 = add i64 %r960, 19
  %r962 = inttoptr i64 %r961 to ptr
  %r963 = trunc i64 3 to i8
  store volatile i8 %r963, ptr %r962
  %r964 = load i64, i64* %ptr_dns
  %r965 = add i64 %r964, 20
  %r966 = inttoptr i64 %r965 to ptr
  %r967 = trunc i64 99 to i8
  store volatile i8 %r967, ptr %r966
  %r968 = load i64, i64* %ptr_dns
  %r969 = add i64 %r968, 21
  %r970 = inttoptr i64 %r969 to ptr
  %r971 = trunc i64 111 to i8
  store volatile i8 %r971, ptr %r970
  %r972 = load i64, i64* %ptr_dns
  %r973 = add i64 %r972, 22
  %r974 = inttoptr i64 %r973 to ptr
  %r975 = trunc i64 109 to i8
  store volatile i8 %r975, ptr %r974
  %r976 = load i64, i64* %ptr_dns
  %r977 = add i64 %r976, 23
  %r978 = inttoptr i64 %r977 to ptr
  %r979 = trunc i64 0 to i8
  store volatile i8 %r979, ptr %r978
  %r980 = load i64, i64* %ptr_dns
  %r981 = add i64 %r980, 24
  %r982 = inttoptr i64 %r981 to ptr
  %r983 = trunc i64 0 to i8
  store volatile i8 %r983, ptr %r982
  %r984 = load i64, i64* %ptr_dns
  %r985 = add i64 %r984, 25
  %r986 = inttoptr i64 %r985 to ptr
  %r987 = trunc i64 1 to i8
  store volatile i8 %r987, ptr %r986
  %r988 = load i64, i64* %ptr_dns
  %r989 = add i64 %r988, 26
  %r990 = inttoptr i64 %r989 to ptr
  %r991 = trunc i64 0 to i8
  store volatile i8 %r991, ptr %r990
  %r992 = load i64, i64* %ptr_dns
  %r993 = add i64 %r992, 27
  %r994 = inttoptr i64 %r993 to ptr
  %r995 = trunc i64 1 to i8
  store volatile i8 %r995, ptr %r994
  %r996 = getelementptr [53 x i8], [53 x i8]* @.str.474, i64 0, i64 0
  %r997 = ptrtoint i8* %r996 to i64
  store i64 %r997, i64* %ptr_out
  %r998 = load i64, i64* @E1000_BAR
  %r999 = add i64 %r998, 21504
  %r1000 = inttoptr i64 %r999 to i32*
  %r1001 = load volatile i32, i32* %r1000
  %r1002 = zext i32 %r1001 to i64
  store i64 %r1002, i64* %ptr_flush
  %r1003 = load i64, i64* %ptr_frame
  %r1004 = call i64 @e1000_transmit(i64 %r1003, i64 70)
  store i64 %r1004, i64* %ptr_status_ptr
  store i64 100000, i64* %ptr_timeout
  store i64 0, i64* %ptr_done
  br label %L1470
L1470:
  %r1005 = load i64, i64* %ptr_timeout
  %r1007 = icmp sgt i64 %r1005, 0
  %r1006 = zext i1 %r1007 to i64
  store i64 0, i64* @.sc.475
  %r1009 = icmp ne i64 %r1006, 0
  br i1 %r1009, label %L1473, label %L1474
L1473:
  %r1010 = load i64, i64* %ptr_done
  %r1011 = call i64 @_eq(i64 %r1010, i64 0)
  %r1012 = icmp ne i64 %r1011, 0
  %r1013 = zext i1 %r1012 to i64
  store i64 %r1013, i64* @.sc.475
  br label %L1474
L1474:
  %r1008 = load i64, i64* @.sc.475
  %r1014 = icmp ne i64 %r1008, 0
  br i1 %r1014, label %L1471, label %L1472
L1471:
  %r1015 = load i64, i64* @E1000_BAR
  %r1016 = add i64 %r1015, 14352
  %r1017 = inttoptr i64 %r1016 to i32*
  %r1018 = load volatile i32, i32* %r1017
  %r1019 = zext i32 %r1018 to i64
  store i64 %r1019, i64* %ptr_head
  %r1020 = load i64, i64* %ptr_head
  %r1021 = load i64, i64* @E1000_TX_TAIL
  %r1022 = call i64 @_eq(i64 %r1020, i64 %r1021)
  %r1023 = icmp ne i64 %r1022, 0
  br i1 %r1023, label %L1475, label %L1477
L1475:
  store i64 1, i64* %ptr_done
  br label %L1477
L1477:
  %r1024 = load i64, i64* %ptr_timeout
  %r1025 = sub i64 %r1024, 1
  store i64 %r1025, i64* %ptr_timeout
  br label %L1470
L1472:
  %r1026 = load i64, i64* %ptr_done
  %r1027 = icmp ne i64 %r1026, 0
  br i1 %r1027, label %L1478, label %L1479
L1478:
  %r1028 = load i64, i64* %ptr_out
  %r1029 = getelementptr [56 x i8], [56 x i8]* @.str.476, i64 0, i64 0
  %r1030 = ptrtoint i8* %r1029 to i64
  %r1031 = call i64 @_add(i64 %r1028, i64 %r1030)
  store i64 %r1031, i64* %ptr_out
  store i64 20000000, i64* %ptr_rx_timeout
  store i64 0, i64* %ptr_reply_pkt
  br label %L1481
L1481:
  %r1032 = load i64, i64* %ptr_rx_timeout
  %r1034 = icmp sgt i64 %r1032, 0
  %r1033 = zext i1 %r1034 to i64
  store i64 0, i64* @.sc.477
  %r1036 = icmp ne i64 %r1033, 0
  br i1 %r1036, label %L1484, label %L1485
L1484:
  %r1037 = load i64, i64* %ptr_reply_pkt
  %r1038 = call i64 @_eq(i64 %r1037, i64 0)
  %r1039 = icmp ne i64 %r1038, 0
  %r1040 = zext i1 %r1039 to i64
  store i64 %r1040, i64* @.sc.477
  br label %L1485
L1485:
  %r1035 = load i64, i64* @.sc.477
  %r1041 = icmp ne i64 %r1035, 0
  br i1 %r1041, label %L1482, label %L1483
L1482:
  %r1042 = load i64, i64* @E1000_BAR
  %r1043 = add i64 %r1042, 10256
  %r1044 = inttoptr i64 %r1043 to i32*
  %r1045 = load volatile i32, i32* %r1044
  %r1046 = zext i32 %r1045 to i64
  store i64 %r1046, i64* %ptr_yield
  %r1047 = call i64 @e1000_poll_rx()
  store i64 %r1047, i64* %ptr_tmp_pkt
  %r1048 = load i64, i64* %ptr_tmp_pkt
  %r1050 = call i64 @_eq(i64 %r1048, i64 0)
  %r1049 = xor i64 %r1050, 1
  %r1051 = icmp ne i64 %r1049, 0
  br i1 %r1051, label %L1486, label %L1488
L1486:
  %r1052 = load i64, i64* %ptr_tmp_pkt
  %r1053 = add i64 %r1052, 12
  %r1054 = inttoptr i64 %r1053 to ptr
  %r1055 = load volatile i8, ptr %r1054
  %r1056 = zext i8 %r1055 to i64
  store i64 %r1056, i64* %ptr_e_type
  %r1057 = load i64, i64* %ptr_e_type
  %r1058 = call i64 @_eq(i64 %r1057, i64 8)
  %r1059 = icmp ne i64 %r1058, 0
  br i1 %r1059, label %L1489, label %L1491
L1489:
  %r1060 = load i64, i64* %ptr_tmp_pkt
  %r1061 = add i64 %r1060, 23
  %r1062 = inttoptr i64 %r1061 to ptr
  %r1063 = load volatile i8, ptr %r1062
  %r1064 = zext i8 %r1063 to i64
  store i64 %r1064, i64* %ptr_proto
  %r1065 = load i64, i64* %ptr_proto
  %r1066 = call i64 @_eq(i64 %r1065, i64 17)
  %r1067 = icmp ne i64 %r1066, 0
  br i1 %r1067, label %L1492, label %L1494
L1492:
  %r1068 = load i64, i64* %ptr_tmp_pkt
  store i64 %r1068, i64* %ptr_reply_pkt
  br label %L1494
L1494:
  br label %L1491
L1491:
  br label %L1488
L1488:
  %r1069 = load i64, i64* %ptr_rx_timeout
  %r1070 = sub i64 %r1069, 1
  store i64 %r1070, i64* %ptr_rx_timeout
  br label %L1481
L1483:
  %r1071 = load i64, i64* %ptr_reply_pkt
  %r1073 = call i64 @_eq(i64 %r1071, i64 0)
  %r1072 = xor i64 %r1073, 1
  %r1074 = icmp ne i64 %r1072, 0
  br i1 %r1074, label %L1495, label %L1496
L1495:
  %r1075 = load i64, i64* %ptr_out
  %r1076 = getelementptr [41 x i8], [41 x i8]* @.str.478, i64 0, i64 0
  %r1077 = ptrtoint i8* %r1076 to i64
  %r1078 = call i64 @_add(i64 %r1075, i64 %r1077)
  store i64 %r1078, i64* %ptr_out
  %r1079 = load i64, i64* %ptr_reply_pkt
  %r1080 = add i64 %r1079, 82
  %r1081 = inttoptr i64 %r1080 to ptr
  %r1082 = load volatile i8, ptr %r1081
  %r1083 = zext i8 %r1082 to i64
  store i64 %r1083, i64* %ptr_ip1
  %r1084 = load i64, i64* %ptr_reply_pkt
  %r1085 = add i64 %r1084, 83
  %r1086 = inttoptr i64 %r1085 to ptr
  %r1087 = load volatile i8, ptr %r1086
  %r1088 = zext i8 %r1087 to i64
  store i64 %r1088, i64* %ptr_ip2
  %r1089 = load i64, i64* %ptr_reply_pkt
  %r1090 = add i64 %r1089, 84
  %r1091 = inttoptr i64 %r1090 to ptr
  %r1092 = load volatile i8, ptr %r1091
  %r1093 = zext i8 %r1092 to i64
  store i64 %r1093, i64* %ptr_ip3
  %r1094 = load i64, i64* %ptr_reply_pkt
  %r1095 = add i64 %r1094, 85
  %r1096 = inttoptr i64 %r1095 to ptr
  %r1097 = load volatile i8, ptr %r1096
  %r1098 = zext i8 %r1097 to i64
  store i64 %r1098, i64* %ptr_ip4
  %r1099 = load i64, i64* %ptr_out
  %r1100 = getelementptr [23 x i8], [23 x i8]* @.str.479, i64 0, i64 0
  %r1101 = ptrtoint i8* %r1100 to i64
  %r1102 = call i64 @_add(i64 %r1099, i64 %r1101)
  %r1103 = load i64, i64* %ptr_ip1
  %r1104 = call i64 @int_to_str(i64 %r1103)
  %r1105 = call i64 @_add(i64 %r1102, i64 %r1104)
  %r1106 = getelementptr [2 x i8], [2 x i8]* @.str.480, i64 0, i64 0
  %r1107 = ptrtoint i8* %r1106 to i64
  %r1108 = call i64 @_add(i64 %r1105, i64 %r1107)
  %r1109 = load i64, i64* %ptr_ip2
  %r1110 = call i64 @int_to_str(i64 %r1109)
  %r1111 = call i64 @_add(i64 %r1108, i64 %r1110)
  %r1112 = getelementptr [2 x i8], [2 x i8]* @.str.481, i64 0, i64 0
  %r1113 = ptrtoint i8* %r1112 to i64
  %r1114 = call i64 @_add(i64 %r1111, i64 %r1113)
  %r1115 = load i64, i64* %ptr_ip3
  %r1116 = call i64 @int_to_str(i64 %r1115)
  %r1117 = call i64 @_add(i64 %r1114, i64 %r1116)
  %r1118 = getelementptr [2 x i8], [2 x i8]* @.str.482, i64 0, i64 0
  %r1119 = ptrtoint i8* %r1118 to i64
  %r1120 = call i64 @_add(i64 %r1117, i64 %r1119)
  %r1121 = load i64, i64* %ptr_ip4
  %r1122 = call i64 @int_to_str(i64 %r1121)
  %r1123 = call i64 @_add(i64 %r1120, i64 %r1122)
  %r1124 = getelementptr [2 x i8], [2 x i8]* @.str.483, i64 0, i64 0
  %r1125 = ptrtoint i8* %r1124 to i64
  %r1126 = call i64 @_add(i64 %r1123, i64 %r1125)
  store i64 %r1126, i64* %ptr_out
  br label %L1497
L1496:
  %r1127 = load i64, i64* %ptr_out
  %r1128 = getelementptr [45 x i8], [45 x i8]* @.str.484, i64 0, i64 0
  %r1129 = ptrtoint i8* %r1128 to i64
  %r1130 = call i64 @_add(i64 %r1127, i64 %r1129)
  store i64 %r1130, i64* %ptr_out
  br label %L1497
L1497:
  br label %L1480
L1479:
  %r1131 = load i64, i64* %ptr_out
  %r1132 = getelementptr [39 x i8], [39 x i8]* @.str.485, i64 0, i64 0
  %r1133 = ptrtoint i8* %r1132 to i64
  %r1134 = call i64 @_add(i64 %r1131, i64 %r1133)
  store i64 %r1134, i64* %ptr_out
  br label %L1480
L1480:
  br label %L1466
L1466:
  br label %L1463
L1462:
  %r1135 = load i64, i64* %ptr_cmd
  %r1136 = getelementptr [11 x i8], [11 x i8]* @.str.486, i64 0, i64 0
  %r1137 = ptrtoint i8* %r1136 to i64
  %r1138 = call i64 @_eq(i64 %r1135, i64 %r1137)
  %r1139 = icmp ne i64 %r1138, 0
  br i1 %r1139, label %L1498, label %L1499
L1498:
  %r1140 = load i64, i64* @E1000_BAR
  %r1141 = call i64 @_eq(i64 %r1140, i64 0)
  %r1142 = icmp ne i64 %r1141, 0
  br i1 %r1142, label %L1501, label %L1502
L1501:
  %r1143 = getelementptr [37 x i8], [37 x i8]* @.str.487, i64 0, i64 0
  %r1144 = ptrtoint i8* %r1143 to i64
  store i64 %r1144, i64* %ptr_out
  br label %L1503
L1502:
  %r1145 = getelementptr [56 x i8], [56 x i8]* @.str.488, i64 0, i64 0
  %r1146 = ptrtoint i8* %r1145 to i64
  store i64 %r1146, i64* %ptr_out
  br label %L1504
L1504:
  %r1147 = call i64 @e1000_poll_rx()
  %r1149 = call i64 @_eq(i64 %r1147, i64 0)
  %r1148 = xor i64 %r1149, 1
  %r1150 = icmp ne i64 %r1148, 0
  br i1 %r1150, label %L1505, label %L1506
L1505:
  br label %L1504
L1506:
  %r1151 = call i64 @malloc(i64 64)
  store i64 %r1151, i64* %ptr_f
  %r1152 = load i64, i64* %ptr_f
  %r1153 = call i64 @fast_fill32(i64 %r1152, i64 0, i64 16)
  %r1154 = load i64, i64* %ptr_f
  %r1155 = add i64 %r1154, 0
  %r1156 = inttoptr i64 %r1155 to ptr
  %r1157 = trunc i64 82 to i8
  store volatile i8 %r1157, ptr %r1156
  %r1158 = load i64, i64* %ptr_f
  %r1159 = add i64 %r1158, 1
  %r1160 = inttoptr i64 %r1159 to ptr
  %r1161 = trunc i64 85 to i8
  store volatile i8 %r1161, ptr %r1160
  %r1162 = load i64, i64* %ptr_f
  %r1163 = add i64 %r1162, 2
  %r1164 = inttoptr i64 %r1163 to ptr
  %r1165 = trunc i64 10 to i8
  store volatile i8 %r1165, ptr %r1164
  %r1166 = load i64, i64* %ptr_f
  %r1167 = add i64 %r1166, 3
  %r1168 = inttoptr i64 %r1167 to ptr
  %r1169 = trunc i64 0 to i8
  store volatile i8 %r1169, ptr %r1168
  %r1170 = load i64, i64* %ptr_f
  %r1171 = add i64 %r1170, 4
  %r1172 = inttoptr i64 %r1171 to ptr
  %r1173 = trunc i64 2 to i8
  store volatile i8 %r1173, ptr %r1172
  %r1174 = load i64, i64* %ptr_f
  %r1175 = add i64 %r1174, 5
  %r1176 = inttoptr i64 %r1175 to ptr
  %r1177 = trunc i64 2 to i8
  store volatile i8 %r1177, ptr %r1176
  %r1178 = load i64, i64* @E1000_BAR
  %r1179 = add i64 %r1178, 21504
  %r1180 = inttoptr i64 %r1179 to i32*
  %r1181 = load volatile i32, i32* %r1180
  %r1182 = zext i32 %r1181 to i64
  store i64 %r1182, i64* %ptr_ral
  %r1183 = load i64, i64* @E1000_BAR
  %r1184 = add i64 %r1183, 21508
  %r1185 = inttoptr i64 %r1184 to i32*
  %r1186 = load volatile i32, i32* %r1185
  %r1187 = zext i32 %r1186 to i64
  store i64 %r1187, i64* %ptr_rah
  %r1188 = load i64, i64* %ptr_f
  %r1189 = add i64 %r1188, 6
  %r1190 = load i64, i64* %ptr_ral
  %r1191 = and i64 %r1190, 255
  %r1192 = inttoptr i64 %r1189 to ptr
  %r1193 = trunc i64 %r1191 to i8
  store volatile i8 %r1193, ptr %r1192
  %r1194 = load i64, i64* %ptr_f
  %r1195 = add i64 %r1194, 7
  %r1196 = load i64, i64* %ptr_ral
  %r1197 = lshr i64 %r1196, 8
  %r1198 = and i64 %r1197, 255
  %r1199 = inttoptr i64 %r1195 to ptr
  %r1200 = trunc i64 %r1198 to i8
  store volatile i8 %r1200, ptr %r1199
  %r1201 = load i64, i64* %ptr_f
  %r1202 = add i64 %r1201, 8
  %r1203 = load i64, i64* %ptr_ral
  %r1204 = lshr i64 %r1203, 16
  %r1205 = and i64 %r1204, 255
  %r1206 = inttoptr i64 %r1202 to ptr
  %r1207 = trunc i64 %r1205 to i8
  store volatile i8 %r1207, ptr %r1206
  %r1208 = load i64, i64* %ptr_f
  %r1209 = add i64 %r1208, 9
  %r1210 = load i64, i64* %ptr_ral
  %r1211 = lshr i64 %r1210, 24
  %r1212 = and i64 %r1211, 255
  %r1213 = inttoptr i64 %r1209 to ptr
  %r1214 = trunc i64 %r1212 to i8
  store volatile i8 %r1214, ptr %r1213
  %r1215 = load i64, i64* %ptr_f
  %r1216 = add i64 %r1215, 10
  %r1217 = load i64, i64* %ptr_rah
  %r1218 = and i64 %r1217, 255
  %r1219 = inttoptr i64 %r1216 to ptr
  %r1220 = trunc i64 %r1218 to i8
  store volatile i8 %r1220, ptr %r1219
  %r1221 = load i64, i64* %ptr_f
  %r1222 = add i64 %r1221, 11
  %r1223 = load i64, i64* %ptr_rah
  %r1224 = lshr i64 %r1223, 8
  %r1225 = and i64 %r1224, 255
  %r1226 = inttoptr i64 %r1222 to ptr
  %r1227 = trunc i64 %r1225 to i8
  store volatile i8 %r1227, ptr %r1226
  %r1228 = load i64, i64* %ptr_f
  %r1229 = add i64 %r1228, 12
  %r1230 = inttoptr i64 %r1229 to ptr
  %r1231 = trunc i64 8 to i8
  store volatile i8 %r1231, ptr %r1230
  %r1232 = load i64, i64* %ptr_f
  %r1233 = add i64 %r1232, 13
  %r1234 = inttoptr i64 %r1233 to ptr
  %r1235 = trunc i64 0 to i8
  store volatile i8 %r1235, ptr %r1234
  %r1236 = load i64, i64* %ptr_f
  %r1237 = add i64 %r1236, 14
  store i64 %r1237, i64* %ptr_ip
  %r1238 = load i64, i64* %ptr_ip
  %r1239 = add i64 %r1238, 0
  %r1240 = inttoptr i64 %r1239 to ptr
  %r1241 = trunc i64 69 to i8
  store volatile i8 %r1241, ptr %r1240
  %r1242 = load i64, i64* %ptr_ip
  %r1243 = add i64 %r1242, 1
  %r1244 = inttoptr i64 %r1243 to ptr
  %r1245 = trunc i64 0 to i8
  store volatile i8 %r1245, ptr %r1244
  %r1246 = load i64, i64* %ptr_ip
  %r1247 = add i64 %r1246, 2
  %r1248 = inttoptr i64 %r1247 to ptr
  %r1249 = trunc i64 0 to i8
  store volatile i8 %r1249, ptr %r1248
  %r1250 = load i64, i64* %ptr_ip
  %r1251 = add i64 %r1250, 3
  %r1252 = inttoptr i64 %r1251 to ptr
  %r1253 = trunc i64 40 to i8
  store volatile i8 %r1253, ptr %r1252
  %r1254 = load i64, i64* %ptr_ip
  %r1255 = add i64 %r1254, 4
  %r1256 = inttoptr i64 %r1255 to ptr
  %r1257 = trunc i64 17 to i8
  store volatile i8 %r1257, ptr %r1256
  %r1258 = load i64, i64* %ptr_ip
  %r1259 = add i64 %r1258, 5
  %r1260 = inttoptr i64 %r1259 to ptr
  %r1261 = trunc i64 17 to i8
  store volatile i8 %r1261, ptr %r1260
  %r1262 = load i64, i64* %ptr_ip
  %r1263 = add i64 %r1262, 6
  %r1264 = inttoptr i64 %r1263 to ptr
  %r1265 = trunc i64 64 to i8
  store volatile i8 %r1265, ptr %r1264
  %r1266 = load i64, i64* %ptr_ip
  %r1267 = add i64 %r1266, 7
  %r1268 = inttoptr i64 %r1267 to ptr
  %r1269 = trunc i64 0 to i8
  store volatile i8 %r1269, ptr %r1268
  %r1270 = load i64, i64* %ptr_ip
  %r1271 = add i64 %r1270, 8
  %r1272 = inttoptr i64 %r1271 to ptr
  %r1273 = trunc i64 64 to i8
  store volatile i8 %r1273, ptr %r1272
  %r1274 = load i64, i64* %ptr_ip
  %r1275 = add i64 %r1274, 9
  %r1276 = inttoptr i64 %r1275 to ptr
  %r1277 = trunc i64 6 to i8
  store volatile i8 %r1277, ptr %r1276
  %r1278 = load i64, i64* %ptr_ip
  %r1279 = add i64 %r1278, 10
  %r1280 = inttoptr i64 %r1279 to ptr
  %r1281 = trunc i64 27 to i8
  store volatile i8 %r1281, ptr %r1280
  %r1282 = load i64, i64* %ptr_ip
  %r1283 = add i64 %r1282, 11
  %r1284 = inttoptr i64 %r1283 to ptr
  %r1285 = trunc i64 175 to i8
  store volatile i8 %r1285, ptr %r1284
  %r1286 = load i64, i64* %ptr_ip
  %r1287 = add i64 %r1286, 12
  %r1288 = inttoptr i64 %r1287 to ptr
  %r1289 = trunc i64 10 to i8
  store volatile i8 %r1289, ptr %r1288
  %r1290 = load i64, i64* %ptr_ip
  %r1291 = add i64 %r1290, 13
  %r1292 = inttoptr i64 %r1291 to ptr
  %r1293 = trunc i64 0 to i8
  store volatile i8 %r1293, ptr %r1292
  %r1294 = load i64, i64* %ptr_ip
  %r1295 = add i64 %r1294, 14
  %r1296 = inttoptr i64 %r1295 to ptr
  %r1297 = trunc i64 2 to i8
  store volatile i8 %r1297, ptr %r1296
  %r1298 = load i64, i64* %ptr_ip
  %r1299 = add i64 %r1298, 15
  %r1300 = inttoptr i64 %r1299 to ptr
  %r1301 = trunc i64 15 to i8
  store volatile i8 %r1301, ptr %r1300
  %r1302 = load i64, i64* %ptr_ip
  %r1303 = add i64 %r1302, 16
  %r1304 = inttoptr i64 %r1303 to ptr
  %r1305 = trunc i64 1 to i8
  store volatile i8 %r1305, ptr %r1304
  %r1306 = load i64, i64* %ptr_ip
  %r1307 = add i64 %r1306, 17
  %r1308 = inttoptr i64 %r1307 to ptr
  %r1309 = trunc i64 1 to i8
  store volatile i8 %r1309, ptr %r1308
  %r1310 = load i64, i64* %ptr_ip
  %r1311 = add i64 %r1310, 18
  %r1312 = inttoptr i64 %r1311 to ptr
  %r1313 = trunc i64 1 to i8
  store volatile i8 %r1313, ptr %r1312
  %r1314 = load i64, i64* %ptr_ip
  %r1315 = add i64 %r1314, 19
  %r1316 = inttoptr i64 %r1315 to ptr
  %r1317 = trunc i64 1 to i8
  store volatile i8 %r1317, ptr %r1316
  %r1318 = load i64, i64* %ptr_f
  %r1319 = add i64 %r1318, 34
  store i64 %r1319, i64* %ptr_tcp
  %r1320 = load i64, i64* %ptr_tcp
  %r1321 = add i64 %r1320, 0
  %r1322 = inttoptr i64 %r1321 to ptr
  %r1323 = trunc i64 192 to i8
  store volatile i8 %r1323, ptr %r1322
  %r1324 = load i64, i64* %ptr_tcp
  %r1325 = add i64 %r1324, 1
  %r1326 = inttoptr i64 %r1325 to ptr
  %r1327 = trunc i64 0 to i8
  store volatile i8 %r1327, ptr %r1326
  %r1328 = load i64, i64* %ptr_tcp
  %r1329 = add i64 %r1328, 2
  %r1330 = inttoptr i64 %r1329 to ptr
  %r1331 = trunc i64 0 to i8
  store volatile i8 %r1331, ptr %r1330
  %r1332 = load i64, i64* %ptr_tcp
  %r1333 = add i64 %r1332, 3
  %r1334 = inttoptr i64 %r1333 to ptr
  %r1335 = trunc i64 80 to i8
  store volatile i8 %r1335, ptr %r1334
  %r1336 = load i64, i64* %ptr_tcp
  %r1337 = add i64 %r1336, 4
  %r1338 = inttoptr i64 %r1337 to ptr
  %r1339 = trunc i64 0 to i8
  store volatile i8 %r1339, ptr %r1338
  %r1340 = load i64, i64* %ptr_tcp
  %r1341 = add i64 %r1340, 5
  %r1342 = inttoptr i64 %r1341 to ptr
  %r1343 = trunc i64 0 to i8
  store volatile i8 %r1343, ptr %r1342
  %r1344 = load i64, i64* %ptr_tcp
  %r1345 = add i64 %r1344, 6
  %r1346 = inttoptr i64 %r1345 to ptr
  %r1347 = trunc i64 0 to i8
  store volatile i8 %r1347, ptr %r1346
  %r1348 = load i64, i64* %ptr_tcp
  %r1349 = add i64 %r1348, 7
  %r1350 = inttoptr i64 %r1349 to ptr
  %r1351 = trunc i64 0 to i8
  store volatile i8 %r1351, ptr %r1350
  %r1352 = load i64, i64* %ptr_tcp
  %r1353 = add i64 %r1352, 8
  %r1354 = inttoptr i64 %r1353 to ptr
  %r1355 = trunc i64 0 to i8
  store volatile i8 %r1355, ptr %r1354
  %r1356 = load i64, i64* %ptr_tcp
  %r1357 = add i64 %r1356, 9
  %r1358 = inttoptr i64 %r1357 to ptr
  %r1359 = trunc i64 0 to i8
  store volatile i8 %r1359, ptr %r1358
  %r1360 = load i64, i64* %ptr_tcp
  %r1361 = add i64 %r1360, 10
  %r1362 = inttoptr i64 %r1361 to ptr
  %r1363 = trunc i64 0 to i8
  store volatile i8 %r1363, ptr %r1362
  %r1364 = load i64, i64* %ptr_tcp
  %r1365 = add i64 %r1364, 11
  %r1366 = inttoptr i64 %r1365 to ptr
  %r1367 = trunc i64 0 to i8
  store volatile i8 %r1367, ptr %r1366
  %r1368 = load i64, i64* %ptr_tcp
  %r1369 = add i64 %r1368, 12
  %r1370 = inttoptr i64 %r1369 to ptr
  %r1371 = trunc i64 80 to i8
  store volatile i8 %r1371, ptr %r1370
  %r1372 = load i64, i64* %ptr_tcp
  %r1373 = add i64 %r1372, 13
  %r1374 = inttoptr i64 %r1373 to ptr
  %r1375 = trunc i64 2 to i8
  store volatile i8 %r1375, ptr %r1374
  %r1376 = load i64, i64* %ptr_tcp
  %r1377 = add i64 %r1376, 14
  %r1378 = inttoptr i64 %r1377 to ptr
  %r1379 = trunc i64 255 to i8
  store volatile i8 %r1379, ptr %r1378
  %r1380 = load i64, i64* %ptr_tcp
  %r1381 = add i64 %r1380, 15
  %r1382 = inttoptr i64 %r1381 to ptr
  %r1383 = trunc i64 255 to i8
  store volatile i8 %r1383, ptr %r1382
  %r1384 = load i64, i64* %ptr_tcp
  %r1385 = add i64 %r1384, 16
  %r1386 = inttoptr i64 %r1385 to ptr
  %r1387 = trunc i64 225 to i8
  store volatile i8 %r1387, ptr %r1386
  %r1388 = load i64, i64* %ptr_tcp
  %r1389 = add i64 %r1388, 17
  %r1390 = inttoptr i64 %r1389 to ptr
  %r1391 = trunc i64 129 to i8
  store volatile i8 %r1391, ptr %r1390
  %r1392 = load i64, i64* %ptr_tcp
  %r1393 = add i64 %r1392, 18
  %r1394 = inttoptr i64 %r1393 to ptr
  %r1395 = trunc i64 0 to i8
  store volatile i8 %r1395, ptr %r1394
  %r1396 = load i64, i64* %ptr_tcp
  %r1397 = add i64 %r1396, 19
  %r1398 = inttoptr i64 %r1397 to ptr
  %r1399 = trunc i64 0 to i8
  store volatile i8 %r1399, ptr %r1398
  %r1400 = load i64, i64* %ptr_f
  %r1401 = call i64 @e1000_transmit(i64 %r1400, i64 64)
  store i64 100000000, i64* %ptr_rx_timeout
  store i64 0, i64* %ptr_caught
  br label %L1507
L1507:
  %r1402 = load i64, i64* %ptr_rx_timeout
  %r1404 = icmp sgt i64 %r1402, 0
  %r1403 = zext i1 %r1404 to i64
  store i64 0, i64* @.sc.489
  %r1406 = icmp ne i64 %r1403, 0
  br i1 %r1406, label %L1510, label %L1511
L1510:
  %r1407 = load i64, i64* %ptr_caught
  %r1408 = call i64 @_eq(i64 %r1407, i64 0)
  %r1409 = icmp ne i64 %r1408, 0
  %r1410 = zext i1 %r1409 to i64
  store i64 %r1410, i64* @.sc.489
  br label %L1511
L1511:
  %r1405 = load i64, i64* @.sc.489
  %r1411 = icmp ne i64 %r1405, 0
  br i1 %r1411, label %L1508, label %L1509
L1508:
  %r1412 = load i64, i64* @E1000_BAR
  %r1413 = add i64 %r1412, 10256
  %r1414 = inttoptr i64 %r1413 to i32*
  %r1415 = load volatile i32, i32* %r1414
  %r1416 = zext i32 %r1415 to i64
  store i64 %r1416, i64* %ptr_yield
  %r1417 = call i64 @e1000_poll_rx()
  store i64 %r1417, i64* %ptr_tmp_pkt
  %r1418 = load i64, i64* %ptr_tmp_pkt
  %r1420 = call i64 @_eq(i64 %r1418, i64 0)
  %r1419 = xor i64 %r1420, 1
  %r1421 = icmp ne i64 %r1419, 0
  br i1 %r1421, label %L1512, label %L1514
L1512:
  %r1422 = load i64, i64* %ptr_tmp_pkt
  %r1423 = add i64 %r1422, 12
  %r1424 = inttoptr i64 %r1423 to ptr
  %r1425 = load volatile i8, ptr %r1424
  %r1426 = zext i8 %r1425 to i64
  store i64 %r1426, i64* %ptr_e_hi
  %r1427 = load i64, i64* %ptr_tmp_pkt
  %r1428 = add i64 %r1427, 13
  %r1429 = inttoptr i64 %r1428 to ptr
  %r1430 = load volatile i8, ptr %r1429
  %r1431 = zext i8 %r1430 to i64
  store i64 %r1431, i64* %ptr_e_lo
  %r1432 = load i64, i64* %ptr_e_hi
  %r1433 = call i64 @_eq(i64 %r1432, i64 8)
  store i64 0, i64* @.sc.490
  %r1435 = icmp ne i64 %r1433, 0
  br i1 %r1435, label %L1515, label %L1516
L1515:
  %r1436 = load i64, i64* %ptr_e_lo
  %r1437 = call i64 @_eq(i64 %r1436, i64 0)
  %r1438 = icmp ne i64 %r1437, 0
  %r1439 = zext i1 %r1438 to i64
  store i64 %r1439, i64* @.sc.490
  br label %L1516
L1516:
  %r1434 = load i64, i64* @.sc.490
  %r1440 = icmp ne i64 %r1434, 0
  br i1 %r1440, label %L1517, label %L1519
L1517:
  %r1441 = load i64, i64* %ptr_tmp_pkt
  store i64 %r1441, i64* %ptr_caught
  br label %L1519
L1519:
  br label %L1514
L1514:
  %r1442 = load i64, i64* %ptr_rx_timeout
  %r1443 = sub i64 %r1442, 1
  store i64 %r1443, i64* %ptr_rx_timeout
  br label %L1507
L1509:
  %r1444 = load i64, i64* %ptr_caught
  %r1446 = call i64 @_eq(i64 %r1444, i64 0)
  %r1445 = xor i64 %r1446, 1
  %r1447 = icmp ne i64 %r1445, 0
  br i1 %r1447, label %L1520, label %L1521
L1520:
  %r1448 = getelementptr [15 x i8], [15 x i8]* @.str.491, i64 0, i64 0
  %r1449 = ptrtoint i8* %r1448 to i64
  store i64 %r1449, i64* %ptr_dump
  store i64 0, i64* %ptr_k
  br label %L1523
L1523:
  %r1450 = load i64, i64* %ptr_k
  %r1452 = icmp slt i64 %r1450, 54
  %r1451 = zext i1 %r1452 to i64
  %r1453 = icmp ne i64 %r1451, 0
  br i1 %r1453, label %L1524, label %L1525
L1524:
  %r1454 = load i64, i64* %ptr_dump
  %r1455 = load i64, i64* %ptr_caught
  %r1456 = load i64, i64* %ptr_k
  %r1457 = add i64 %r1455, %r1456
  %r1458 = inttoptr i64 %r1457 to ptr
  %r1459 = load volatile i8, ptr %r1458
  %r1460 = zext i8 %r1459 to i64
  %r1461 = call i64 @int_to_str(i64 %r1460)
  %r1462 = call i64 @_add(i64 %r1454, i64 %r1461)
  %r1463 = getelementptr [2 x i8], [2 x i8]* @.str.492, i64 0, i64 0
  %r1464 = ptrtoint i8* %r1463 to i64
  %r1465 = call i64 @_add(i64 %r1462, i64 %r1464)
  store i64 %r1465, i64* %ptr_dump
  %r1466 = load i64, i64* %ptr_k
  %r1467 = call i64 @_add(i64 %r1466, i64 1)
  store i64 %r1467, i64* %ptr_k
  br label %L1523
L1525:
  %r1468 = load i64, i64* %ptr_out
  %r1469 = load i64, i64* %ptr_dump
  %r1470 = call i64 @_add(i64 %r1468, i64 %r1469)
  %r1471 = getelementptr [2 x i8], [2 x i8]* @.str.493, i64 0, i64 0
  %r1472 = ptrtoint i8* %r1471 to i64
  %r1473 = call i64 @_add(i64 %r1470, i64 %r1472)
  store i64 %r1473, i64* %ptr_out
  br label %L1522
L1521:
  %r1474 = load i64, i64* %ptr_out
  %r1475 = getelementptr [51 x i8], [51 x i8]* @.str.494, i64 0, i64 0
  %r1476 = ptrtoint i8* %r1475 to i64
  %r1477 = call i64 @_add(i64 %r1474, i64 %r1476)
  store i64 %r1477, i64* %ptr_out
  br label %L1522
L1522:
  br label %L1503
L1503:
  br label %L1500
L1499:
  %r1478 = load i64, i64* %ptr_cmd
  %r1479 = getelementptr [10 x i8], [10 x i8]* @.str.495, i64 0, i64 0
  %r1480 = ptrtoint i8* %r1479 to i64
  %r1481 = call i64 @_eq(i64 %r1478, i64 %r1480)
  %r1482 = icmp ne i64 %r1481, 0
  br i1 %r1482, label %L1526, label %L1527
L1526:
  %r1483 = load i64, i64* @E1000_BAR
  %r1484 = call i64 @_eq(i64 %r1483, i64 0)
  %r1485 = icmp ne i64 %r1484, 0
  br i1 %r1485, label %L1529, label %L1530
L1529:
  %r1486 = getelementptr [37 x i8], [37 x i8]* @.str.496, i64 0, i64 0
  %r1487 = ptrtoint i8* %r1486 to i64
  store i64 %r1487, i64* %ptr_out
  br label %L1531
L1530:
  %r1488 = getelementptr [38 x i8], [38 x i8]* @.str.497, i64 0, i64 0
  %r1489 = ptrtoint i8* %r1488 to i64
  store i64 %r1489, i64* %ptr_out
  br label %L1532
L1532:
  %r1490 = call i64 @e1000_poll_rx()
  %r1492 = call i64 @_eq(i64 %r1490, i64 0)
  %r1491 = xor i64 %r1492, 1
  %r1493 = icmp ne i64 %r1491, 0
  br i1 %r1493, label %L1533, label %L1534
L1533:
  br label %L1532
L1534:
  %r1494 = load i64, i64* @tcp_global_seq
  %r1495 = call i64 @_add(i64 %r1494, i64 1000)
  store i64 %r1495, i64* @tcp_global_seq
  %r1496 = load i64, i64* @tcp_global_seq
  %r1497 = srem i64 %r1496, 10000
  %r1498 = call i64 @_add(i64 40000, i64 %r1497)
  store i64 %r1498, i64* %ptr_my_port
  %r1499 = load i64, i64* @tcp_global_seq
  store i64 %r1499, i64* %ptr_my_seq
  %r1500 = load i64, i64* %ptr_my_port
  %r1501 = load i64, i64* %ptr_my_seq
  %r1502 = call i64 @e1000_send_syn(i64 %r1500, i64 %r1501)
  store i64 %r1502, i64* %ptr_tx_frame
  store i64 200000, i64* %ptr_rx_timeout
  store i64 0, i64* %ptr_caught
  br label %L1535
L1535:
  %r1503 = load i64, i64* %ptr_rx_timeout
  %r1505 = icmp sgt i64 %r1503, 0
  %r1504 = zext i1 %r1505 to i64
  store i64 0, i64* @.sc.498
  %r1507 = icmp ne i64 %r1504, 0
  br i1 %r1507, label %L1538, label %L1539
L1538:
  %r1508 = load i64, i64* %ptr_caught
  %r1509 = call i64 @_eq(i64 %r1508, i64 0)
  %r1510 = icmp ne i64 %r1509, 0
  %r1511 = zext i1 %r1510 to i64
  store i64 %r1511, i64* @.sc.498
  br label %L1539
L1539:
  %r1506 = load i64, i64* @.sc.498
  %r1512 = icmp ne i64 %r1506, 0
  br i1 %r1512, label %L1536, label %L1537
L1536:
  %r1513 = load i64, i64* @E1000_BAR
  %r1514 = add i64 %r1513, 10256
  %r1515 = inttoptr i64 %r1514 to i32*
  %r1516 = load volatile i32, i32* %r1515
  %r1517 = zext i32 %r1516 to i64
  store i64 %r1517, i64* %ptr_yield
  %r1518 = call i64 @e1000_poll_rx()
  store i64 %r1518, i64* %ptr_tmp_pkt
  %r1519 = load i64, i64* %ptr_tmp_pkt
  %r1521 = call i64 @_eq(i64 %r1519, i64 0)
  %r1520 = xor i64 %r1521, 1
  %r1522 = icmp ne i64 %r1520, 0
  br i1 %r1522, label %L1540, label %L1542
L1540:
  %r1523 = load i64, i64* %ptr_tmp_pkt
  %r1524 = add i64 %r1523, 12
  %r1525 = inttoptr i64 %r1524 to ptr
  %r1526 = load volatile i8, ptr %r1525
  %r1527 = zext i8 %r1526 to i64
  store i64 %r1527, i64* %ptr_e_hi
  %r1528 = load i64, i64* %ptr_e_hi
  %r1530 = icmp slt i64 %r1528, 0
  %r1529 = zext i1 %r1530 to i64
  %r1531 = icmp ne i64 %r1529, 0
  br i1 %r1531, label %L1543, label %L1545
L1543:
  %r1532 = load i64, i64* %ptr_e_hi
  %r1533 = call i64 @_add(i64 %r1532, i64 256)
  store i64 %r1533, i64* %ptr_e_hi
  br label %L1545
L1545:
  %r1534 = load i64, i64* %ptr_tmp_pkt
  %r1535 = add i64 %r1534, 13
  %r1536 = inttoptr i64 %r1535 to ptr
  %r1537 = load volatile i8, ptr %r1536
  %r1538 = zext i8 %r1537 to i64
  store i64 %r1538, i64* %ptr_e_lo
  %r1539 = load i64, i64* %ptr_e_lo
  %r1541 = icmp slt i64 %r1539, 0
  %r1540 = zext i1 %r1541 to i64
  %r1542 = icmp ne i64 %r1540, 0
  br i1 %r1542, label %L1546, label %L1548
L1546:
  %r1543 = load i64, i64* %ptr_e_lo
  %r1544 = call i64 @_add(i64 %r1543, i64 256)
  store i64 %r1544, i64* %ptr_e_lo
  br label %L1548
L1548:
  %r1545 = load i64, i64* %ptr_e_hi
  %r1546 = call i64 @_eq(i64 %r1545, i64 8)
  store i64 0, i64* @.sc.499
  %r1548 = icmp ne i64 %r1546, 0
  br i1 %r1548, label %L1549, label %L1550
L1549:
  %r1549 = load i64, i64* %ptr_e_lo
  %r1550 = call i64 @_eq(i64 %r1549, i64 0)
  %r1551 = icmp ne i64 %r1550, 0
  %r1552 = zext i1 %r1551 to i64
  store i64 %r1552, i64* @.sc.499
  br label %L1550
L1550:
  %r1547 = load i64, i64* @.sc.499
  %r1553 = icmp ne i64 %r1547, 0
  br i1 %r1553, label %L1551, label %L1553
L1551:
  %r1554 = load i64, i64* %ptr_tmp_pkt
  store i64 %r1554, i64* %ptr_caught
  br label %L1553
L1553:
  br label %L1542
L1542:
  %r1555 = load i64, i64* %ptr_rx_timeout
  %r1556 = sub i64 %r1555, 1
  store i64 %r1556, i64* %ptr_rx_timeout
  br label %L1535
L1537:
  %r1557 = load i64, i64* %ptr_caught
  %r1559 = call i64 @_eq(i64 %r1557, i64 0)
  %r1558 = xor i64 %r1559, 1
  %r1560 = icmp ne i64 %r1558, 0
  br i1 %r1560, label %L1554, label %L1555
L1554:
  %r1561 = load i64, i64* %ptr_caught
  %r1562 = add i64 %r1561, 14
  %r1563 = inttoptr i64 %r1562 to ptr
  %r1564 = load volatile i8, ptr %r1563
  %r1565 = zext i8 %r1564 to i64
  store i64 %r1565, i64* %ptr_ip_ihl_ver
  %r1566 = load i64, i64* %ptr_ip_ihl_ver
  %r1568 = icmp slt i64 %r1566, 0
  %r1567 = zext i1 %r1568 to i64
  %r1569 = icmp ne i64 %r1567, 0
  br i1 %r1569, label %L1557, label %L1559
L1557:
  %r1570 = load i64, i64* %ptr_ip_ihl_ver
  %r1571 = call i64 @_add(i64 %r1570, i64 256)
  store i64 %r1571, i64* %ptr_ip_ihl_ver
  br label %L1559
L1559:
  %r1572 = load i64, i64* %ptr_ip_ihl_ver
  %r1573 = srem i64 %r1572, 16
  %r1574 = mul i64 %r1573, 4
  store i64 %r1574, i64* %ptr_ip_hdr_len
  %r1575 = load i64, i64* %ptr_ip_hdr_len
  %r1576 = call i64 @_add(i64 14, i64 %r1575)
  store i64 %r1576, i64* %ptr_tcp_start
  %r1577 = load i64, i64* %ptr_caught
  %r1578 = add i64 %r1577, 23
  %r1579 = inttoptr i64 %r1578 to ptr
  %r1580 = load volatile i8, ptr %r1579
  %r1581 = zext i8 %r1580 to i64
  store i64 %r1581, i64* %ptr_proto
  %r1582 = load i64, i64* %ptr_proto
  %r1584 = icmp slt i64 %r1582, 0
  %r1583 = zext i1 %r1584 to i64
  %r1585 = icmp ne i64 %r1583, 0
  br i1 %r1585, label %L1560, label %L1562
L1560:
  %r1586 = load i64, i64* %ptr_proto
  %r1587 = call i64 @_add(i64 %r1586, i64 256)
  store i64 %r1587, i64* %ptr_proto
  br label %L1562
L1562:
  %r1588 = load i64, i64* %ptr_proto
  %r1589 = call i64 @_eq(i64 %r1588, i64 6)
  %r1590 = icmp ne i64 %r1589, 0
  br i1 %r1590, label %L1563, label %L1564
L1563:
  %r1591 = load i64, i64* %ptr_caught
  %r1592 = load i64, i64* %ptr_tcp_start
  %r1593 = call i64 @_add(i64 %r1592, i64 13)
  %r1594 = add i64 %r1591, %r1593
  %r1595 = inttoptr i64 %r1594 to ptr
  %r1596 = load volatile i8, ptr %r1595
  %r1597 = zext i8 %r1596 to i64
  store i64 %r1597, i64* %ptr_flags
  %r1598 = load i64, i64* %ptr_flags
  %r1600 = icmp slt i64 %r1598, 0
  %r1599 = zext i1 %r1600 to i64
  %r1601 = icmp ne i64 %r1599, 0
  br i1 %r1601, label %L1566, label %L1568
L1566:
  %r1602 = load i64, i64* %ptr_flags
  %r1603 = call i64 @_add(i64 %r1602, i64 256)
  store i64 %r1603, i64* %ptr_flags
  br label %L1568
L1568:
  %r1604 = load i64, i64* %ptr_flags
  %r1605 = call i64 @_eq(i64 %r1604, i64 18)
  store i64 1, i64* @.sc.500
  %r1607 = icmp eq i64 %r1605, 0
  br i1 %r1607, label %L1569, label %L1570
L1569:
  %r1608 = load i64, i64* %ptr_flags
  %r1609 = call i64 @_eq(i64 %r1608, i64 26)
  %r1610 = icmp ne i64 %r1609, 0
  %r1611 = zext i1 %r1610 to i64
  store i64 %r1611, i64* @.sc.500
  br label %L1570
L1570:
  %r1606 = load i64, i64* @.sc.500
  %r1612 = icmp ne i64 %r1606, 0
  br i1 %r1612, label %L1571, label %L1572
L1571:
  %r1613 = load i64, i64* %ptr_out
  %r1614 = getelementptr [51 x i8], [51 x i8]* @.str.501, i64 0, i64 0
  %r1615 = ptrtoint i8* %r1614 to i64
  %r1616 = call i64 @_add(i64 %r1613, i64 %r1615)
  store i64 %r1616, i64* %ptr_out
  %r1617 = load i64, i64* %ptr_caught
  %r1618 = load i64, i64* %ptr_tcp_start
  %r1619 = call i64 @_add(i64 %r1618, i64 4)
  %r1620 = add i64 %r1617, %r1619
  %r1621 = inttoptr i64 %r1620 to ptr
  %r1622 = load volatile i8, ptr %r1621
  %r1623 = zext i8 %r1622 to i64
  store i64 %r1623, i64* %ptr_s_seq1
  %r1624 = load i64, i64* %ptr_s_seq1
  %r1626 = icmp slt i64 %r1624, 0
  %r1625 = zext i1 %r1626 to i64
  %r1627 = icmp ne i64 %r1625, 0
  br i1 %r1627, label %L1574, label %L1576
L1574:
  %r1628 = load i64, i64* %ptr_s_seq1
  %r1629 = call i64 @_add(i64 %r1628, i64 256)
  store i64 %r1629, i64* %ptr_s_seq1
  br label %L1576
L1576:
  %r1630 = load i64, i64* %ptr_caught
  %r1631 = load i64, i64* %ptr_tcp_start
  %r1632 = call i64 @_add(i64 %r1631, i64 5)
  %r1633 = add i64 %r1630, %r1632
  %r1634 = inttoptr i64 %r1633 to ptr
  %r1635 = load volatile i8, ptr %r1634
  %r1636 = zext i8 %r1635 to i64
  store i64 %r1636, i64* %ptr_s_seq2
  %r1637 = load i64, i64* %ptr_s_seq2
  %r1639 = icmp slt i64 %r1637, 0
  %r1638 = zext i1 %r1639 to i64
  %r1640 = icmp ne i64 %r1638, 0
  br i1 %r1640, label %L1577, label %L1579
L1577:
  %r1641 = load i64, i64* %ptr_s_seq2
  %r1642 = call i64 @_add(i64 %r1641, i64 256)
  store i64 %r1642, i64* %ptr_s_seq2
  br label %L1579
L1579:
  %r1643 = load i64, i64* %ptr_caught
  %r1644 = load i64, i64* %ptr_tcp_start
  %r1645 = call i64 @_add(i64 %r1644, i64 6)
  %r1646 = add i64 %r1643, %r1645
  %r1647 = inttoptr i64 %r1646 to ptr
  %r1648 = load volatile i8, ptr %r1647
  %r1649 = zext i8 %r1648 to i64
  store i64 %r1649, i64* %ptr_s_seq3
  %r1650 = load i64, i64* %ptr_s_seq3
  %r1652 = icmp slt i64 %r1650, 0
  %r1651 = zext i1 %r1652 to i64
  %r1653 = icmp ne i64 %r1651, 0
  br i1 %r1653, label %L1580, label %L1582
L1580:
  %r1654 = load i64, i64* %ptr_s_seq3
  %r1655 = call i64 @_add(i64 %r1654, i64 256)
  store i64 %r1655, i64* %ptr_s_seq3
  br label %L1582
L1582:
  %r1656 = load i64, i64* %ptr_caught
  %r1657 = load i64, i64* %ptr_tcp_start
  %r1658 = call i64 @_add(i64 %r1657, i64 7)
  %r1659 = add i64 %r1656, %r1658
  %r1660 = inttoptr i64 %r1659 to ptr
  %r1661 = load volatile i8, ptr %r1660
  %r1662 = zext i8 %r1661 to i64
  store i64 %r1662, i64* %ptr_s_seq4
  %r1663 = load i64, i64* %ptr_s_seq4
  %r1665 = icmp slt i64 %r1663, 0
  %r1664 = zext i1 %r1665 to i64
  %r1666 = icmp ne i64 %r1664, 0
  br i1 %r1666, label %L1583, label %L1585
L1583:
  %r1667 = load i64, i64* %ptr_s_seq4
  %r1668 = call i64 @_add(i64 %r1667, i64 256)
  store i64 %r1668, i64* %ptr_s_seq4
  br label %L1585
L1585:
  %r1669 = load i64, i64* %ptr_s_seq4
  %r1670 = call i64 @_add(i64 %r1669, i64 1)
  store i64 %r1670, i64* %ptr_s_seq4
  %r1671 = load i64, i64* %ptr_s_seq4
  %r1673 = icmp sgt i64 %r1671, 255
  %r1672 = zext i1 %r1673 to i64
  %r1674 = icmp ne i64 %r1672, 0
  br i1 %r1674, label %L1586, label %L1588
L1586:
  store i64 0, i64* %ptr_s_seq4
  %r1675 = load i64, i64* %ptr_s_seq3
  %r1676 = call i64 @_add(i64 %r1675, i64 1)
  store i64 %r1676, i64* %ptr_s_seq3
  br label %L1588
L1588:
  %r1677 = load i64, i64* %ptr_s_seq3
  %r1679 = icmp sgt i64 %r1677, 255
  %r1678 = zext i1 %r1679 to i64
  %r1680 = icmp ne i64 %r1678, 0
  br i1 %r1680, label %L1589, label %L1591
L1589:
  store i64 0, i64* %ptr_s_seq3
  %r1681 = load i64, i64* %ptr_s_seq2
  %r1682 = call i64 @_add(i64 %r1681, i64 1)
  store i64 %r1682, i64* %ptr_s_seq2
  br label %L1591
L1591:
  %r1683 = load i64, i64* %ptr_s_seq2
  %r1685 = icmp sgt i64 %r1683, 255
  %r1684 = zext i1 %r1685 to i64
  %r1686 = icmp ne i64 %r1684, 0
  br i1 %r1686, label %L1592, label %L1594
L1592:
  store i64 0, i64* %ptr_s_seq2
  %r1687 = load i64, i64* %ptr_s_seq1
  %r1688 = call i64 @_add(i64 %r1687, i64 1)
  store i64 %r1688, i64* %ptr_s_seq1
  br label %L1594
L1594:
  %r1689 = load i64, i64* %ptr_s_seq1
  %r1691 = icmp sgt i64 %r1689, 255
  %r1690 = zext i1 %r1691 to i64
  %r1692 = icmp ne i64 %r1690, 0
  br i1 %r1692, label %L1595, label %L1597
L1595:
  store i64 0, i64* %ptr_s_seq1
  br label %L1597
L1597:
  %r1693 = load i64, i64* %ptr_my_port
  %r1694 = load i64, i64* %ptr_my_seq
  %r1695 = call i64 @_add(i64 %r1694, i64 1)
  %r1696 = load i64, i64* %ptr_s_seq1
  %r1697 = load i64, i64* %ptr_s_seq2
  %r1698 = load i64, i64* %ptr_s_seq3
  %r1699 = load i64, i64* %ptr_s_seq4
  %r1700 = call i64 @e1000_send_ack(i64 %r1693, i64 %r1695, i64 %r1696, i64 %r1697, i64 %r1698, i64 %r1699)
  store i64 500000, i64* %ptr_slirp_delay
  br label %L1598
L1598:
  %r1701 = load i64, i64* %ptr_slirp_delay
  %r1703 = icmp sgt i64 %r1701, 0
  %r1702 = zext i1 %r1703 to i64
  %r1704 = icmp ne i64 %r1702, 0
  br i1 %r1704, label %L1599, label %L1600
L1599:
  %r1705 = load i64, i64* %ptr_slirp_delay
  %r1706 = sub i64 %r1705, 1
  store i64 %r1706, i64* %ptr_slirp_delay
  br label %L1598
L1600:
  %r1707 = load i64, i64* %ptr_out
  %r1708 = getelementptr [54 x i8], [54 x i8]* @.str.502, i64 0, i64 0
  %r1709 = ptrtoint i8* %r1708 to i64
  %r1710 = call i64 @_add(i64 %r1707, i64 %r1709)
  store i64 %r1710, i64* %ptr_out
  %r1711 = load i64, i64* %ptr_my_port
  %r1712 = load i64, i64* %ptr_my_seq
  %r1713 = call i64 @_add(i64 %r1712, i64 1)
  %r1714 = load i64, i64* %ptr_s_seq1
  %r1715 = load i64, i64* %ptr_s_seq2
  %r1716 = load i64, i64* %ptr_s_seq3
  %r1717 = load i64, i64* %ptr_s_seq4
  %r1718 = call i64 @e1000_send_get(i64 %r1711, i64 %r1713, i64 %r1714, i64 %r1715, i64 %r1716, i64 %r1717)
  store i64 200000, i64* %ptr_rx_timeout
  store i64 0, i64* %ptr_http_pkt
  br label %L1601
L1601:
  %r1719 = load i64, i64* %ptr_rx_timeout
  %r1721 = icmp sgt i64 %r1719, 0
  %r1720 = zext i1 %r1721 to i64
  store i64 0, i64* @.sc.503
  %r1723 = icmp ne i64 %r1720, 0
  br i1 %r1723, label %L1604, label %L1605
L1604:
  %r1724 = load i64, i64* %ptr_http_pkt
  %r1725 = call i64 @_eq(i64 %r1724, i64 0)
  %r1726 = icmp ne i64 %r1725, 0
  %r1727 = zext i1 %r1726 to i64
  store i64 %r1727, i64* @.sc.503
  br label %L1605
L1605:
  %r1722 = load i64, i64* @.sc.503
  %r1728 = icmp ne i64 %r1722, 0
  br i1 %r1728, label %L1602, label %L1603
L1602:
  %r1729 = load i64, i64* @E1000_BAR
  %r1730 = add i64 %r1729, 10256
  %r1731 = inttoptr i64 %r1730 to i32*
  %r1732 = load volatile i32, i32* %r1731
  %r1733 = zext i32 %r1732 to i64
  store i64 %r1733, i64* %ptr_yield_rx
  %r1734 = call i64 @e1000_poll_rx()
  store i64 %r1734, i64* %ptr_h_pkt
  %r1735 = load i64, i64* %ptr_h_pkt
  %r1737 = call i64 @_eq(i64 %r1735, i64 0)
  %r1736 = xor i64 %r1737, 1
  %r1738 = icmp ne i64 %r1736, 0
  br i1 %r1738, label %L1606, label %L1608
L1606:
  %r1739 = load i64, i64* %ptr_h_pkt
  %r1740 = add i64 %r1739, 12
  %r1741 = inttoptr i64 %r1740 to ptr
  %r1742 = load volatile i8, ptr %r1741
  %r1743 = zext i8 %r1742 to i64
  store i64 %r1743, i64* %ptr_e_h_hi
  %r1744 = load i64, i64* %ptr_e_h_hi
  %r1746 = icmp slt i64 %r1744, 0
  %r1745 = zext i1 %r1746 to i64
  %r1747 = icmp ne i64 %r1745, 0
  br i1 %r1747, label %L1609, label %L1611
L1609:
  %r1748 = load i64, i64* %ptr_e_h_hi
  %r1749 = call i64 @_add(i64 %r1748, i64 256)
  store i64 %r1749, i64* %ptr_e_h_hi
  br label %L1611
L1611:
  %r1750 = load i64, i64* %ptr_h_pkt
  %r1751 = add i64 %r1750, 13
  %r1752 = inttoptr i64 %r1751 to ptr
  %r1753 = load volatile i8, ptr %r1752
  %r1754 = zext i8 %r1753 to i64
  store i64 %r1754, i64* %ptr_e_h_lo
  %r1755 = load i64, i64* %ptr_e_h_lo
  %r1757 = icmp slt i64 %r1755, 0
  %r1756 = zext i1 %r1757 to i64
  %r1758 = icmp ne i64 %r1756, 0
  br i1 %r1758, label %L1612, label %L1614
L1612:
  %r1759 = load i64, i64* %ptr_e_h_lo
  %r1760 = call i64 @_add(i64 %r1759, i64 256)
  store i64 %r1760, i64* %ptr_e_h_lo
  br label %L1614
L1614:
  %r1761 = load i64, i64* %ptr_e_h_hi
  %r1762 = call i64 @_eq(i64 %r1761, i64 8)
  store i64 0, i64* @.sc.504
  %r1764 = icmp ne i64 %r1762, 0
  br i1 %r1764, label %L1615, label %L1616
L1615:
  %r1765 = load i64, i64* %ptr_e_h_lo
  %r1766 = call i64 @_eq(i64 %r1765, i64 0)
  %r1767 = icmp ne i64 %r1766, 0
  %r1768 = zext i1 %r1767 to i64
  store i64 %r1768, i64* @.sc.504
  br label %L1616
L1616:
  %r1763 = load i64, i64* @.sc.504
  %r1769 = icmp ne i64 %r1763, 0
  br i1 %r1769, label %L1617, label %L1619
L1617:
  %r1770 = load i64, i64* %ptr_h_pkt
  %r1771 = add i64 %r1770, 23
  %r1772 = inttoptr i64 %r1771 to ptr
  %r1773 = load volatile i8, ptr %r1772
  %r1774 = zext i8 %r1773 to i64
  store i64 %r1774, i64* %ptr_h_proto
  %r1775 = load i64, i64* %ptr_h_proto
  %r1777 = icmp slt i64 %r1775, 0
  %r1776 = zext i1 %r1777 to i64
  %r1778 = icmp ne i64 %r1776, 0
  br i1 %r1778, label %L1620, label %L1622
L1620:
  %r1779 = load i64, i64* %ptr_h_proto
  %r1780 = call i64 @_add(i64 %r1779, i64 256)
  store i64 %r1780, i64* %ptr_h_proto
  br label %L1622
L1622:
  %r1781 = load i64, i64* %ptr_h_proto
  %r1782 = call i64 @_eq(i64 %r1781, i64 6)
  %r1783 = icmp ne i64 %r1782, 0
  br i1 %r1783, label %L1623, label %L1625
L1623:
  %r1784 = load i64, i64* %ptr_h_pkt
  %r1785 = add i64 %r1784, 14
  %r1786 = inttoptr i64 %r1785 to ptr
  %r1787 = load volatile i8, ptr %r1786
  %r1788 = zext i8 %r1787 to i64
  store i64 %r1788, i64* %ptr_h_ihl
  %r1789 = load i64, i64* %ptr_h_ihl
  %r1791 = icmp slt i64 %r1789, 0
  %r1790 = zext i1 %r1791 to i64
  %r1792 = icmp ne i64 %r1790, 0
  br i1 %r1792, label %L1626, label %L1628
L1626:
  %r1793 = load i64, i64* %ptr_h_ihl
  %r1794 = call i64 @_add(i64 %r1793, i64 256)
  store i64 %r1794, i64* %ptr_h_ihl
  br label %L1628
L1628:
  %r1795 = load i64, i64* %ptr_h_ihl
  %r1796 = srem i64 %r1795, 16
  %r1797 = mul i64 %r1796, 4
  store i64 %r1797, i64* %ptr_h_ip_len
  %r1798 = load i64, i64* %ptr_h_ip_len
  %r1799 = call i64 @_add(i64 14, i64 %r1798)
  store i64 %r1799, i64* %ptr_h_tcp_start
  %r1800 = load i64, i64* %ptr_h_pkt
  %r1801 = load i64, i64* %ptr_h_tcp_start
  %r1802 = call i64 @_add(i64 %r1801, i64 12)
  %r1803 = add i64 %r1800, %r1802
  %r1804 = inttoptr i64 %r1803 to ptr
  %r1805 = load volatile i8, ptr %r1804
  %r1806 = zext i8 %r1805 to i64
  store i64 %r1806, i64* %ptr_data_off
  %r1807 = load i64, i64* %ptr_data_off
  %r1809 = icmp slt i64 %r1807, 0
  %r1808 = zext i1 %r1809 to i64
  %r1810 = icmp ne i64 %r1808, 0
  br i1 %r1810, label %L1629, label %L1631
L1629:
  %r1811 = load i64, i64* %ptr_data_off
  %r1812 = call i64 @_add(i64 %r1811, i64 256)
  store i64 %r1812, i64* %ptr_data_off
  br label %L1631
L1631:
  %r1813 = load i64, i64* %ptr_data_off
  %r1814 = sdiv i64 %r1813, 16
  %r1815 = mul i64 %r1814, 4
  store i64 %r1815, i64* %ptr_h_tcp_hdr_len
  %r1816 = load i64, i64* %ptr_h_pkt
  %r1817 = add i64 %r1816, 16
  %r1818 = inttoptr i64 %r1817 to ptr
  %r1819 = load volatile i8, ptr %r1818
  %r1820 = zext i8 %r1819 to i64
  store i64 %r1820, i64* %ptr_ip_b1
  %r1821 = load i64, i64* %ptr_ip_b1
  %r1823 = icmp slt i64 %r1821, 0
  %r1822 = zext i1 %r1823 to i64
  %r1824 = icmp ne i64 %r1822, 0
  br i1 %r1824, label %L1632, label %L1634
L1632:
  %r1825 = load i64, i64* %ptr_ip_b1
  %r1826 = call i64 @_add(i64 %r1825, i64 256)
  store i64 %r1826, i64* %ptr_ip_b1
  br label %L1634
L1634:
  %r1827 = load i64, i64* %ptr_h_pkt
  %r1828 = add i64 %r1827, 17
  %r1829 = inttoptr i64 %r1828 to ptr
  %r1830 = load volatile i8, ptr %r1829
  %r1831 = zext i8 %r1830 to i64
  store i64 %r1831, i64* %ptr_ip_b2
  %r1832 = load i64, i64* %ptr_ip_b2
  %r1834 = icmp slt i64 %r1832, 0
  %r1833 = zext i1 %r1834 to i64
  %r1835 = icmp ne i64 %r1833, 0
  br i1 %r1835, label %L1635, label %L1637
L1635:
  %r1836 = load i64, i64* %ptr_ip_b2
  %r1837 = call i64 @_add(i64 %r1836, i64 256)
  store i64 %r1837, i64* %ptr_ip_b2
  br label %L1637
L1637:
  %r1838 = load i64, i64* %ptr_ip_b1
  %r1839 = mul i64 %r1838, 256
  %r1840 = load i64, i64* %ptr_ip_b2
  %r1841 = call i64 @_add(i64 %r1839, i64 %r1840)
  store i64 %r1841, i64* %ptr_ip_tot_len
  %r1842 = load i64, i64* %ptr_ip_tot_len
  %r1843 = load i64, i64* %ptr_h_ip_len
  %r1844 = sub i64 %r1842, %r1843
  %r1845 = load i64, i64* %ptr_h_tcp_hdr_len
  %r1846 = sub i64 %r1844, %r1845
  store i64 %r1846, i64* %ptr_p_size
  %r1847 = load i64, i64* %ptr_p_size
  %r1849 = icmp sgt i64 %r1847, 0
  %r1848 = zext i1 %r1849 to i64
  %r1850 = icmp ne i64 %r1848, 0
  br i1 %r1850, label %L1638, label %L1640
L1638:
  %r1851 = load i64, i64* %ptr_h_pkt
  store i64 %r1851, i64* %ptr_http_pkt
  %r1852 = load i64, i64* %ptr_p_size
  store i64 %r1852, i64* @E1000_RX_LEN
  %r1853 = load i64, i64* %ptr_h_tcp_start
  %r1854 = load i64, i64* %ptr_h_tcp_hdr_len
  %r1855 = call i64 @_add(i64 %r1853, i64 %r1854)
  store i64 %r1855, i64* @E1000_RX_CUR
  br label %L1640
L1640:
  br label %L1625
L1625:
  br label %L1619
L1619:
  br label %L1608
L1608:
  %r1856 = load i64, i64* %ptr_rx_timeout
  %r1857 = sub i64 %r1856, 1
  store i64 %r1857, i64* %ptr_rx_timeout
  br label %L1601
L1603:
  %r1858 = load i64, i64* %ptr_http_pkt
  %r1860 = call i64 @_eq(i64 %r1858, i64 0)
  %r1859 = xor i64 %r1860, 1
  %r1861 = icmp ne i64 %r1859, 0
  br i1 %r1861, label %L1641, label %L1642
L1641:
  %r1862 = load i64, i64* %ptr_out
  %r1863 = getelementptr [37 x i8], [37 x i8]* @.str.505, i64 0, i64 0
  %r1864 = ptrtoint i8* %r1863 to i64
  %r1865 = call i64 @_add(i64 %r1862, i64 %r1864)
  store i64 %r1865, i64* %ptr_out
  %r1866 = load i64, i64* %ptr_out
  %r1867 = getelementptr [50 x i8], [50 x i8]* @.str.506, i64 0, i64 0
  %r1868 = ptrtoint i8* %r1867 to i64
  %r1869 = call i64 @_add(i64 %r1866, i64 %r1868)
  store i64 %r1869, i64* %ptr_out
  %r1870 = load i64, i64* @E1000_RX_CUR
  store i64 %r1870, i64* %ptr_pl_off
  store i64 0, i64* %ptr_p_i
  br label %L1644
L1644:
  %r1871 = load i64, i64* %ptr_p_i
  %r1872 = load i64, i64* @E1000_RX_LEN
  %r1874 = icmp slt i64 %r1871, %r1872
  %r1873 = zext i1 %r1874 to i64
  store i64 0, i64* @.sc.507
  %r1876 = icmp ne i64 %r1873, 0
  br i1 %r1876, label %L1647, label %L1648
L1647:
  %r1877 = load i64, i64* %ptr_p_i
  %r1879 = icmp slt i64 %r1877, 80
  %r1878 = zext i1 %r1879 to i64
  %r1880 = icmp ne i64 %r1878, 0
  %r1881 = zext i1 %r1880 to i64
  store i64 %r1881, i64* @.sc.507
  br label %L1648
L1648:
  %r1875 = load i64, i64* @.sc.507
  %r1882 = icmp ne i64 %r1875, 0
  br i1 %r1882, label %L1645, label %L1646
L1645:
  %r1883 = load i64, i64* %ptr_http_pkt
  %r1884 = load i64, i64* %ptr_pl_off
  %r1885 = load i64, i64* %ptr_p_i
  %r1886 = call i64 @_add(i64 %r1884, i64 %r1885)
  %r1887 = add i64 %r1883, %r1886
  %r1888 = inttoptr i64 %r1887 to ptr
  %r1889 = load volatile i8, ptr %r1888
  %r1890 = zext i8 %r1889 to i64
  store i64 %r1890, i64* %ptr_bc
  %r1891 = load i64, i64* %ptr_bc
  %r1893 = icmp slt i64 %r1891, 0
  %r1892 = zext i1 %r1893 to i64
  %r1894 = icmp ne i64 %r1892, 0
  br i1 %r1894, label %L1649, label %L1651
L1649:
  %r1895 = load i64, i64* %ptr_bc
  %r1896 = call i64 @_add(i64 %r1895, i64 256)
  store i64 %r1896, i64* %ptr_bc
  br label %L1651
L1651:
  %r1897 = load i64, i64* %ptr_bc
  %r1899 = icmp sge i64 %r1897, 32
  %r1898 = zext i1 %r1899 to i64
  store i64 0, i64* @.sc.509
  %r1901 = icmp ne i64 %r1898, 0
  br i1 %r1901, label %L1652, label %L1653
L1652:
  %r1902 = load i64, i64* %ptr_bc
  %r1904 = icmp sle i64 %r1902, 126
  %r1903 = zext i1 %r1904 to i64
  %r1905 = icmp ne i64 %r1903, 0
  %r1906 = zext i1 %r1905 to i64
  store i64 %r1906, i64* @.sc.509
  br label %L1653
L1653:
  %r1900 = load i64, i64* @.sc.509
  store i64 1, i64* @.sc.508
  %r1908 = icmp eq i64 %r1900, 0
  br i1 %r1908, label %L1654, label %L1655
L1654:
  %r1909 = load i64, i64* %ptr_bc
  %r1910 = call i64 @_eq(i64 %r1909, i64 10)
  %r1911 = icmp ne i64 %r1910, 0
  %r1912 = zext i1 %r1911 to i64
  store i64 %r1912, i64* @.sc.508
  br label %L1655
L1655:
  %r1907 = load i64, i64* @.sc.508
  %r1913 = icmp ne i64 %r1907, 0
  br i1 %r1913, label %L1656, label %L1658
L1656:
  %r1914 = load i64, i64* %ptr_out
  %r1915 = load i64, i64* %ptr_bc
  %r1916 = call i64 @signum_ex(i64 %r1915)
  %r1917 = call i64 @_add(i64 %r1914, i64 %r1916)
  store i64 %r1917, i64* %ptr_out
  br label %L1658
L1658:
  %r1918 = load i64, i64* %ptr_p_i
  %r1919 = call i64 @_add(i64 %r1918, i64 1)
  store i64 %r1919, i64* %ptr_p_i
  br label %L1644
L1646:
  %r1920 = load i64, i64* %ptr_out
  %r1921 = getelementptr [33 x i8], [33 x i8]* @.str.510, i64 0, i64 0
  %r1922 = ptrtoint i8* %r1921 to i64
  %r1923 = call i64 @_add(i64 %r1920, i64 %r1922)
  store i64 %r1923, i64* %ptr_out
  br label %L1643
L1642:
  %r1924 = load i64, i64* %ptr_out
  %r1925 = getelementptr [37 x i8], [37 x i8]* @.str.511, i64 0, i64 0
  %r1926 = ptrtoint i8* %r1925 to i64
  %r1927 = call i64 @_add(i64 %r1924, i64 %r1926)
  store i64 %r1927, i64* %ptr_out
  br label %L1643
L1643:
  br label %L1573
L1572:
  %r1928 = load i64, i64* %ptr_out
  %r1929 = getelementptr [41 x i8], [41 x i8]* @.str.512, i64 0, i64 0
  %r1930 = ptrtoint i8* %r1929 to i64
  %r1931 = call i64 @_add(i64 %r1928, i64 %r1930)
  %r1932 = load i64, i64* %ptr_flags
  %r1933 = call i64 @int_to_str(i64 %r1932)
  %r1934 = call i64 @_add(i64 %r1931, i64 %r1933)
  %r1935 = getelementptr [2 x i8], [2 x i8]* @.str.513, i64 0, i64 0
  %r1936 = ptrtoint i8* %r1935 to i64
  %r1937 = call i64 @_add(i64 %r1934, i64 %r1936)
  store i64 %r1937, i64* %ptr_out
  br label %L1573
L1573:
  br label %L1565
L1564:
  %r1938 = load i64, i64* %ptr_out
  %r1939 = getelementptr [49 x i8], [49 x i8]* @.str.514, i64 0, i64 0
  %r1940 = ptrtoint i8* %r1939 to i64
  %r1941 = call i64 @_add(i64 %r1938, i64 %r1940)
  %r1942 = load i64, i64* %ptr_proto
  %r1943 = call i64 @int_to_str(i64 %r1942)
  %r1944 = call i64 @_add(i64 %r1941, i64 %r1943)
  %r1945 = getelementptr [2 x i8], [2 x i8]* @.str.515, i64 0, i64 0
  %r1946 = ptrtoint i8* %r1945 to i64
  %r1947 = call i64 @_add(i64 %r1944, i64 %r1946)
  store i64 %r1947, i64* %ptr_out
  br label %L1565
L1565:
  br label %L1556
L1555:
  %r1948 = load i64, i64* %ptr_out
  %r1949 = getelementptr [41 x i8], [41 x i8]* @.str.516, i64 0, i64 0
  %r1950 = ptrtoint i8* %r1949 to i64
  %r1951 = call i64 @_add(i64 %r1948, i64 %r1950)
  store i64 %r1951, i64* %ptr_out
  %r1952 = getelementptr [13 x i8], [13 x i8]* @.str.517, i64 0, i64 0
  %r1953 = ptrtoint i8* %r1952 to i64
  store i64 %r1953, i64* %ptr_dmp
  store i64 0, i64* %ptr_k
  br label %L1659
L1659:
  %r1954 = load i64, i64* %ptr_k
  %r1956 = icmp slt i64 %r1954, 54
  %r1955 = zext i1 %r1956 to i64
  %r1957 = icmp ne i64 %r1955, 0
  br i1 %r1957, label %L1660, label %L1661
L1660:
  %r1958 = load i64, i64* %ptr_tx_frame
  %r1959 = load i64, i64* %ptr_k
  %r1960 = add i64 %r1958, %r1959
  %r1961 = inttoptr i64 %r1960 to ptr
  %r1962 = load volatile i8, ptr %r1961
  %r1963 = zext i8 %r1962 to i64
  store i64 %r1963, i64* %ptr_d_b
  %r1964 = load i64, i64* %ptr_d_b
  %r1966 = icmp slt i64 %r1964, 0
  %r1965 = zext i1 %r1966 to i64
  %r1967 = icmp ne i64 %r1965, 0
  br i1 %r1967, label %L1662, label %L1664
L1662:
  %r1968 = load i64, i64* %ptr_d_b
  %r1969 = call i64 @_add(i64 %r1968, i64 256)
  store i64 %r1969, i64* %ptr_d_b
  br label %L1664
L1664:
  %r1970 = load i64, i64* %ptr_dmp
  %r1971 = load i64, i64* %ptr_d_b
  %r1972 = call i64 @int_to_str(i64 %r1971)
  %r1973 = call i64 @_add(i64 %r1970, i64 %r1972)
  %r1974 = getelementptr [2 x i8], [2 x i8]* @.str.518, i64 0, i64 0
  %r1975 = ptrtoint i8* %r1974 to i64
  %r1976 = call i64 @_add(i64 %r1973, i64 %r1975)
  store i64 %r1976, i64* %ptr_dmp
  %r1977 = load i64, i64* %ptr_k
  %r1978 = call i64 @_add(i64 %r1977, i64 1)
  store i64 %r1978, i64* %ptr_k
  br label %L1659
L1661:
  %r1979 = load i64, i64* %ptr_out
  %r1980 = load i64, i64* %ptr_dmp
  %r1981 = call i64 @_add(i64 %r1979, i64 %r1980)
  %r1982 = getelementptr [2 x i8], [2 x i8]* @.str.519, i64 0, i64 0
  %r1983 = ptrtoint i8* %r1982 to i64
  %r1984 = call i64 @_add(i64 %r1981, i64 %r1983)
  store i64 %r1984, i64* %ptr_out
  br label %L1556
L1556:
  br label %L1531
L1531:
  br label %L1528
L1527:
  %r1985 = load i64, i64* %ptr_cmd
  %r1986 = getelementptr [6 x i8], [6 x i8]* @.str.520, i64 0, i64 0
  %r1987 = ptrtoint i8* %r1986 to i64
  %r1988 = call i64 @_eq(i64 %r1985, i64 %r1987)
  %r1989 = icmp ne i64 %r1988, 0
  br i1 %r1989, label %L1665, label %L1666
L1665:
  %r1990 = load i64, i64* %ptr_i
  %r1991 = call i64 @remove_actor(i64 %r1990)
  store i64 0, i64* %ptr_is_processing
  br label %L1667
L1666:
  %r1992 = load i64, i64* %ptr_cmd
  %r1993 = call i64 @mensura(i64 %r1992)
  %r1995 = icmp sgt i64 %r1993, 0
  %r1994 = zext i1 %r1995 to i64
  %r1996 = icmp ne i64 %r1994, 0
  br i1 %r1996, label %L1668, label %L1670
L1668:
  %r1997 = getelementptr [10 x i8], [10 x i8]* @.str.521, i64 0, i64 0
  %r1998 = ptrtoint i8* %r1997 to i64
  %r1999 = load i64, i64* %ptr_cmd
  %r2000 = call i64 @_add(i64 %r1998, i64 %r1999)
  %r2001 = getelementptr [2 x i8], [2 x i8]* @.str.522, i64 0, i64 0
  %r2002 = ptrtoint i8* %r2001 to i64
  %r2003 = call i64 @_add(i64 %r2000, i64 %r2002)
  store i64 %r2003, i64* %ptr_out
  br label %L1670
L1670:
  br label %L1667
L1667:
  br label %L1528
L1528:
  br label %L1500
L1500:
  br label %L1463
L1463:
  br label %L1449
L1449:
  br label %L1432
L1432:
  br label %L1415
L1415:
  br label %L1400
L1400:
  br label %L1394
L1394:
  br label %L1391
L1391:
  br label %L1385
L1385:
  br label %L1382
L1382:
  br label %L1379
L1378:
  %r2004 = load i64, i64* %ptr_app_mode
  %r2005 = call i64 @_eq(i64 %r2004, i64 1)
  %r2006 = icmp ne i64 %r2005, 0
  br i1 %r2006, label %L1671, label %L1672
L1671:
  %r2007 = load i64, i64* %ptr_cmd
  %r2008 = getelementptr [10 x i8], [10 x i8]* @.str.523, i64 0, i64 0
  %r2009 = ptrtoint i8* %r2008 to i64
  %r2010 = call i64 @_eq(i64 %r2007, i64 %r2009)
  %r2011 = icmp ne i64 %r2010, 0
  br i1 %r2011, label %L1674, label %L1675
L1674:
  %r2012 = getelementptr [6 x i8], [6 x i8]* @.str.524, i64 0, i64 0
  %r2013 = ptrtoint i8* %r2012 to i64
  store i64 %r2013, i64* %ptr_out
  br label %L1676
L1675:
  %r2014 = load i64, i64* %ptr_cmd
  %r2015 = getelementptr [10 x i8], [10 x i8]* @.str.525, i64 0, i64 0
  %r2016 = ptrtoint i8* %r2015 to i64
  %r2017 = call i64 @_eq(i64 %r2014, i64 %r2016)
  %r2018 = icmp ne i64 %r2017, 0
  br i1 %r2018, label %L1677, label %L1678
L1677:
  store i64 0, i64* %ptr_n
  br label %L1680
L1680:
  %r2019 = load i64, i64* %ptr_n
  %r2020 = load i64, i64* @vfs_name
  %r2021 = call i64 @mensura(i64 %r2020)
  %r2023 = icmp slt i64 %r2019, %r2021
  %r2022 = zext i1 %r2023 to i64
  %r2024 = icmp ne i64 %r2022, 0
  br i1 %r2024, label %L1681, label %L1682
L1681:
  %r2025 = load i64, i64* %ptr_out
  %r2026 = load i64, i64* @vfs_name
  %r2027 = load i64, i64* %ptr_n
  %r2028 = call i64 @_get(i64 %r2026, i64 %r2027)
  %r2029 = call i64 @_add(i64 %r2025, i64 %r2028)
  %r2030 = getelementptr [2 x i8], [2 x i8]* @.str.526, i64 0, i64 0
  %r2031 = ptrtoint i8* %r2030 to i64
  %r2032 = call i64 @_add(i64 %r2029, i64 %r2031)
  store i64 %r2032, i64* %ptr_out
  %r2033 = load i64, i64* %ptr_n
  %r2034 = call i64 @_add(i64 %r2033, i64 1)
  store i64 %r2034, i64* %ptr_n
  br label %L1680
L1682:
  br label %L1679
L1678:
  %r2035 = load i64, i64* %ptr_prefix_rev
  %r2036 = getelementptr [10 x i8], [10 x i8]* @.str.527, i64 0, i64 0
  %r2037 = ptrtoint i8* %r2036 to i64
  %r2038 = call i64 @_eq(i64 %r2035, i64 %r2037)
  %r2039 = icmp ne i64 %r2038, 0
  br i1 %r2039, label %L1683, label %L1684
L1683:
  %r2040 = load i64, i64* %ptr_cmd
  %r2041 = load i64, i64* %ptr_cmd
  %r2042 = call i64 @mensura(i64 %r2041)
  %r2043 = sub i64 %r2042, 9
  %r2044 = call i64 @pars(i64 %r2040, i64 9, i64 %r2043)
  store i64 %r2044, i64* %ptr_fname
  %r2045 = load i64, i64* %ptr_fname
  %r2046 = call i64 @read_file(i64 %r2045)
  %r2047 = getelementptr [2 x i8], [2 x i8]* @.str.528, i64 0, i64 0
  %r2048 = ptrtoint i8* %r2047 to i64
  %r2049 = call i64 @_add(i64 %r2046, i64 %r2048)
  store i64 %r2049, i64* %ptr_out
  br label %L1685
L1684:
  %r2050 = load i64, i64* %ptr_cmd
  %r2051 = getelementptr [6 x i8], [6 x i8]* @.str.529, i64 0, i64 0
  %r2052 = ptrtoint i8* %r2051 to i64
  %r2053 = call i64 @_eq(i64 %r2050, i64 %r2052)
  %r2054 = icmp ne i64 %r2053, 0
  br i1 %r2054, label %L1686, label %L1687
L1686:
  %r2055 = load i64, i64* %ptr_i
  %r2056 = load i64, i64* @actor_app
  call i64 @_set(i64 %r2056, i64 %r2055, i64 0)
  %r2057 = getelementptr [12 x i8], [12 x i8]* @.str.530, i64 0, i64 0
  %r2058 = ptrtoint i8* %r2057 to i64
  store i64 %r2058, i64* %ptr_out
  br label %L1688
L1687:
  %r2059 = load i64, i64* %ptr_cmd
  %r2060 = call i64 @mensura(i64 %r2059)
  %r2062 = icmp sgt i64 %r2060, 0
  %r2061 = zext i1 %r2062 to i64
  %r2063 = icmp ne i64 %r2061, 0
  br i1 %r2063, label %L1689, label %L1691
L1689:
  %r2064 = getelementptr [9 x i8], [9 x i8]* @.str.531, i64 0, i64 0
  %r2065 = ptrtoint i8* %r2064 to i64
  %r2066 = load i64, i64* %ptr_cmd
  %r2067 = call i64 @_add(i64 %r2065, i64 %r2066)
  %r2068 = getelementptr [2 x i8], [2 x i8]* @.str.532, i64 0, i64 0
  %r2069 = ptrtoint i8* %r2068 to i64
  %r2070 = call i64 @_add(i64 %r2067, i64 %r2069)
  store i64 %r2070, i64* %ptr_out
  br label %L1691
L1691:
  br label %L1688
L1688:
  br label %L1685
L1685:
  br label %L1679
L1679:
  br label %L1676
L1676:
  br label %L1673
L1672:
  %r2071 = load i64, i64* %ptr_app_mode
  %r2072 = call i64 @_eq(i64 %r2071, i64 2)
  %r2073 = icmp ne i64 %r2072, 0
  br i1 %r2073, label %L1692, label %L1694
L1692:
  %r2074 = load i64, i64* %ptr_cmd
  %r2075 = getelementptr [3 x i8], [3 x i8]* @.str.533, i64 0, i64 0
  %r2076 = ptrtoint i8* %r2075 to i64
  %r2077 = call i64 @_eq(i64 %r2074, i64 %r2076)
  %r2078 = icmp ne i64 %r2077, 0
  br i1 %r2078, label %L1695, label %L1696
L1695:
  %r2079 = load i64, i64* %ptr_i
  %r2080 = load i64, i64* @actor_app
  call i64 @_set(i64 %r2080, i64 %r2079, i64 0)
  %r2081 = getelementptr [19 x i8], [19 x i8]* @.str.534, i64 0, i64 0
  %r2082 = ptrtoint i8* %r2081 to i64
  store i64 %r2082, i64* %ptr_out
  br label %L1697
L1696:
  %r2083 = load i64, i64* %ptr_cmd
  %r2084 = getelementptr [3 x i8], [3 x i8]* @.str.535, i64 0, i64 0
  %r2085 = ptrtoint i8* %r2084 to i64
  %r2086 = call i64 @_eq(i64 %r2083, i64 %r2085)
  %r2087 = icmp ne i64 %r2086, 0
  br i1 %r2087, label %L1698, label %L1699
L1698:
  %r2088 = load i64, i64* @actor_target
  %r2089 = load i64, i64* %ptr_i
  %r2090 = call i64 @_get(i64 %r2088, i64 %r2089)
  %r2091 = load i64, i64* @actor_file_buf
  %r2092 = load i64, i64* %ptr_i
  %r2093 = call i64 @_get(i64 %r2091, i64 %r2092)
  %r2094 = call i64 @write_file(i64 %r2090, i64 %r2093)
  %r2095 = getelementptr [10 x i8], [10 x i8]* @.str.536, i64 0, i64 0
  %r2096 = ptrtoint i8* %r2095 to i64
  %r2097 = load i64, i64* @actor_target
  %r2098 = load i64, i64* %ptr_i
  %r2099 = call i64 @_get(i64 %r2097, i64 %r2098)
  %r2100 = call i64 @_add(i64 %r2096, i64 %r2099)
  %r2101 = getelementptr [3 x i8], [3 x i8]* @.str.537, i64 0, i64 0
  %r2102 = ptrtoint i8* %r2101 to i64
  %r2103 = call i64 @_add(i64 %r2100, i64 %r2102)
  %r2104 = load i64, i64* @actor_file_buf
  %r2105 = load i64, i64* %ptr_i
  %r2106 = call i64 @_get(i64 %r2104, i64 %r2105)
  %r2107 = call i64 @mensura(i64 %r2106)
  %r2108 = call i64 @int_to_str(i64 %r2107)
  %r2109 = call i64 @_add(i64 %r2103, i64 %r2108)
  %r2110 = getelementptr [5 x i8], [5 x i8]* @.str.538, i64 0, i64 0
  %r2111 = ptrtoint i8* %r2110 to i64
  %r2112 = call i64 @_add(i64 %r2109, i64 %r2111)
  store i64 %r2112, i64* %ptr_out
  br label %L1700
L1699:
  %r2113 = load i64, i64* %ptr_cmd
  %r2114 = getelementptr [4 x i8], [4 x i8]* @.str.539, i64 0, i64 0
  %r2115 = ptrtoint i8* %r2114 to i64
  %r2116 = call i64 @_eq(i64 %r2113, i64 %r2115)
  %r2117 = icmp ne i64 %r2116, 0
  br i1 %r2117, label %L1701, label %L1702
L1701:
  %r2118 = load i64, i64* @actor_target
  %r2119 = load i64, i64* %ptr_i
  %r2120 = call i64 @_get(i64 %r2118, i64 %r2119)
  %r2121 = load i64, i64* @actor_file_buf
  %r2122 = load i64, i64* %ptr_i
  %r2123 = call i64 @_get(i64 %r2121, i64 %r2122)
  %r2124 = call i64 @write_file(i64 %r2120, i64 %r2123)
  %r2125 = load i64, i64* %ptr_i
  %r2126 = load i64, i64* @actor_app
  call i64 @_set(i64 %r2126, i64 %r2125, i64 0)
  %r2127 = getelementptr [22 x i8], [22 x i8]* @.str.540, i64 0, i64 0
  %r2128 = ptrtoint i8* %r2127 to i64
  store i64 %r2128, i64* %ptr_out
  br label %L1703
L1702:
  %r2129 = load i64, i64* %ptr_cmd
  %r2130 = getelementptr [3 x i8], [3 x i8]* @.str.541, i64 0, i64 0
  %r2131 = ptrtoint i8* %r2130 to i64
  %r2132 = call i64 @_eq(i64 %r2129, i64 %r2131)
  %r2133 = icmp ne i64 %r2132, 0
  br i1 %r2133, label %L1704, label %L1705
L1704:
  %r2134 = getelementptr [4 x i8], [4 x i8]* @.str.542, i64 0, i64 0
  %r2135 = ptrtoint i8* %r2134 to i64
  %r2136 = load i64, i64* @actor_target
  %r2137 = load i64, i64* %ptr_i
  %r2138 = call i64 @_get(i64 %r2136, i64 %r2137)
  %r2139 = call i64 @_add(i64 %r2135, i64 %r2138)
  %r2140 = getelementptr [5 x i8], [5 x i8]* @.str.543, i64 0, i64 0
  %r2141 = ptrtoint i8* %r2140 to i64
  %r2142 = call i64 @_add(i64 %r2139, i64 %r2141)
  %r2143 = load i64, i64* @actor_file_buf
  %r2144 = load i64, i64* %ptr_i
  %r2145 = call i64 @_get(i64 %r2143, i64 %r2144)
  %r2146 = call i64 @_add(i64 %r2142, i64 %r2145)
  %r2147 = getelementptr [19 x i8], [19 x i8]* @.str.544, i64 0, i64 0
  %r2148 = ptrtoint i8* %r2147 to i64
  %r2149 = call i64 @_add(i64 %r2146, i64 %r2148)
  store i64 %r2149, i64* %ptr_out
  br label %L1706
L1705:
  %r2150 = load i64, i64* %ptr_cmd
  %r2151 = call i64 @mensura(i64 %r2150)
  %r2153 = icmp sgt i64 %r2151, 0
  %r2152 = zext i1 %r2153 to i64
  %r2154 = icmp ne i64 %r2152, 0
  br i1 %r2154, label %L1707, label %L1709
L1707:
  %r2155 = load i64, i64* @actor_file_buf
  %r2156 = load i64, i64* %ptr_i
  %r2157 = call i64 @_get(i64 %r2155, i64 %r2156)
  %r2158 = load i64, i64* %ptr_cmd
  %r2159 = call i64 @_add(i64 %r2157, i64 %r2158)
  %r2160 = call i64 @signum_ex(i64 10)
  %r2161 = call i64 @_add(i64 %r2159, i64 %r2160)
  %r2162 = load i64, i64* %ptr_i
  %r2163 = load i64, i64* @actor_file_buf
  call i64 @_set(i64 %r2163, i64 %r2162, i64 %r2161)
  br label %L1709
L1709:
  br label %L1706
L1706:
  br label %L1703
L1703:
  br label %L1700
L1700:
  br label %L1697
L1697:
  br label %L1694
L1694:
  br label %L1673
L1673:
  br label %L1379
L1379:
  %r2164 = load i64, i64* %ptr_is_processing
  %r2165 = call i64 @_eq(i64 %r2164, i64 1)
  store i64 0, i64* @.sc.545
  %r2167 = icmp ne i64 %r2165, 0
  br i1 %r2167, label %L1710, label %L1711
L1710:
  %r2168 = load i64, i64* %ptr_should_clear
  %r2169 = call i64 @_eq(i64 %r2168, i64 0)
  %r2170 = icmp ne i64 %r2169, 0
  %r2171 = zext i1 %r2170 to i64
  store i64 %r2171, i64* @.sc.545
  br label %L1711
L1711:
  %r2166 = load i64, i64* @.sc.545
  %r2172 = icmp ne i64 %r2166, 0
  br i1 %r2172, label %L1712, label %L1714
L1712:
  %r2173 = load i64, i64* %ptr_out
  %r2174 = call i64 @mensura(i64 %r2173)
  %r2176 = icmp sgt i64 %r2174, 0
  %r2175 = zext i1 %r2176 to i64
  %r2177 = icmp ne i64 %r2175, 0
  br i1 %r2177, label %L1715, label %L1717
L1715:
  store i64 0, i64* %ptr_routed
  store i64 0, i64* %ptr_w
  br label %L1718
L1718:
  %r2178 = load i64, i64* %ptr_w
  %r2179 = load i64, i64* @wire_from
  %r2180 = call i64 @mensura(i64 %r2179)
  %r2182 = icmp slt i64 %r2178, %r2180
  %r2181 = zext i1 %r2182 to i64
  %r2183 = icmp ne i64 %r2181, 0
  br i1 %r2183, label %L1719, label %L1720
L1719:
  %r2184 = load i64, i64* @wire_from
  %r2185 = load i64, i64* %ptr_w
  %r2186 = call i64 @_get(i64 %r2184, i64 %r2185)
  %r2187 = load i64, i64* %ptr_i
  %r2188 = call i64 @_eq(i64 %r2186, i64 %r2187)
  %r2189 = icmp ne i64 %r2188, 0
  br i1 %r2189, label %L1721, label %L1723
L1721:
  %r2190 = load i64, i64* @wire_to
  %r2191 = load i64, i64* %ptr_w
  %r2192 = call i64 @_get(i64 %r2190, i64 %r2191)
  %r2193 = getelementptr [5 x i8], [5 x i8]* @.str.546, i64 0, i64 0
  %r2194 = ptrtoint i8* %r2193 to i64
  %r2195 = load i64, i64* %ptr_out
  %r2196 = call i64 @_add(i64 %r2194, i64 %r2195)
  %r2197 = call i64 @send_msg(i64 %r2192, i64 %r2196)
  store i64 1, i64* %ptr_routed
  br label %L1723
L1723:
  %r2198 = load i64, i64* %ptr_w
  %r2199 = call i64 @_add(i64 %r2198, i64 1)
  store i64 %r2199, i64* %ptr_w
  br label %L1718
L1720:
  %r2200 = load i64, i64* %ptr_routed
  %r2201 = call i64 @_eq(i64 %r2200, i64 0)
  %r2202 = icmp ne i64 %r2201, 0
  br i1 %r2202, label %L1724, label %L1726
L1724:
  %r2203 = load i64, i64* @actor_text
  %r2204 = load i64, i64* %ptr_i
  %r2205 = call i64 @_get(i64 %r2203, i64 %r2204)
  %r2206 = load i64, i64* %ptr_out
  %r2207 = call i64 @_add(i64 %r2205, i64 %r2206)
  %r2208 = load i64, i64* %ptr_i
  %r2209 = load i64, i64* @actor_text
  call i64 @_set(i64 %r2209, i64 %r2208, i64 %r2207)
  br label %L1726
L1726:
  br label %L1717
L1717:
  %r2210 = getelementptr [3 x i8], [3 x i8]* @.str.547, i64 0, i64 0
  %r2211 = ptrtoint i8* %r2210 to i64
  store i64 %r2211, i64* %ptr_np
  %r2212 = load i64, i64* @actor_app
  %r2213 = load i64, i64* %ptr_i
  %r2214 = call i64 @_get(i64 %r2212, i64 %r2213)
  %r2215 = call i64 @_eq(i64 %r2214, i64 1)
  %r2216 = icmp ne i64 %r2215, 0
  br i1 %r2216, label %L1727, label %L1728
L1727:
  %r2217 = getelementptr [18 x i8], [18 x i8]* @.str.548, i64 0, i64 0
  %r2218 = ptrtoint i8* %r2217 to i64
  store i64 %r2218, i64* %ptr_np
  br label %L1729
L1728:
  %r2219 = load i64, i64* @actor_app
  %r2220 = load i64, i64* %ptr_i
  %r2221 = call i64 @_get(i64 %r2219, i64 %r2220)
  %r2222 = call i64 @_eq(i64 %r2221, i64 2)
  %r2223 = icmp ne i64 %r2222, 0
  br i1 %r2223, label %L1730, label %L1732
L1730:
  %r2224 = getelementptr [10 x i8], [10 x i8]* @.str.549, i64 0, i64 0
  %r2225 = ptrtoint i8* %r2224 to i64
  store i64 %r2225, i64* %ptr_np
  br label %L1732
L1732:
  br label %L1729
L1729:
  %r2226 = load i64, i64* @actor_text
  %r2227 = load i64, i64* %ptr_i
  %r2228 = call i64 @_get(i64 %r2226, i64 %r2227)
  %r2229 = load i64, i64* %ptr_np
  %r2230 = call i64 @_add(i64 %r2228, i64 %r2229)
  %r2231 = load i64, i64* %ptr_i
  %r2232 = load i64, i64* @actor_text
  call i64 @_set(i64 %r2232, i64 %r2231, i64 %r2230)
  br label %L1714
L1714:
  br label %L1364
L1363:
  %r2233 = getelementptr [1 x i8], [1 x i8]* @.str.550, i64 0, i64 0
  %r2234 = ptrtoint i8* %r2233 to i64
  store i64 %r2234, i64* %ptr_prefix_ipc
  %r2235 = load i64, i64* %ptr_msg
  %r2236 = call i64 @mensura(i64 %r2235)
  %r2238 = icmp sge i64 %r2236, 4
  %r2237 = zext i1 %r2238 to i64
  %r2239 = icmp ne i64 %r2237, 0
  br i1 %r2239, label %L1733, label %L1735
L1733:
  %r2240 = load i64, i64* %ptr_msg
  %r2241 = call i64 @pars(i64 %r2240, i64 0, i64 4)
  store i64 %r2241, i64* %ptr_prefix_ipc
  br label %L1735
L1735:
  %r2242 = load i64, i64* %ptr_prefix_ipc
  %r2243 = getelementptr [5 x i8], [5 x i8]* @.str.551, i64 0, i64 0
  %r2244 = ptrtoint i8* %r2243 to i64
  %r2245 = call i64 @_eq(i64 %r2242, i64 %r2244)
  %r2246 = icmp ne i64 %r2245, 0
  br i1 %r2246, label %L1736, label %L1737
L1736:
  %r2247 = load i64, i64* @actor_text
  %r2248 = load i64, i64* %ptr_i
  %r2249 = call i64 @_get(i64 %r2247, i64 %r2248)
  %r2250 = load i64, i64* %ptr_msg
  %r2251 = load i64, i64* %ptr_msg
  %r2252 = call i64 @mensura(i64 %r2251)
  %r2253 = sub i64 %r2252, 4
  %r2254 = call i64 @pars(i64 %r2250, i64 4, i64 %r2253)
  %r2255 = call i64 @_add(i64 %r2249, i64 %r2254)
  %r2256 = load i64, i64* %ptr_i
  %r2257 = load i64, i64* @actor_text
  call i64 @_set(i64 %r2257, i64 %r2256, i64 %r2255)
  br label %L1738
L1737:
  %r2258 = load i64, i64* @actor_text
  %r2259 = load i64, i64* %ptr_i
  %r2260 = call i64 @_get(i64 %r2258, i64 %r2259)
  %r2261 = load i64, i64* %ptr_msg
  %r2262 = call i64 @_add(i64 %r2260, i64 %r2261)
  %r2263 = load i64, i64* %ptr_i
  %r2264 = load i64, i64* @actor_text
  call i64 @_set(i64 %r2264, i64 %r2263, i64 %r2262)
  %r2265 = load i64, i64* @actor_cmd
  %r2266 = load i64, i64* %ptr_i
  %r2267 = call i64 @_get(i64 %r2265, i64 %r2266)
  %r2268 = load i64, i64* %ptr_msg
  %r2269 = call i64 @_add(i64 %r2267, i64 %r2268)
  %r2270 = load i64, i64* %ptr_i
  %r2271 = load i64, i64* @actor_cmd
  call i64 @_set(i64 %r2271, i64 %r2270, i64 %r2269)
  br label %L1738
L1738:
  br label %L1364
L1364:
  br label %L1355
L1355:
  %r2272 = load i64, i64* %ptr_is_processing
  %r2273 = icmp ne i64 %r2272, 0
  br i1 %r2273, label %L1739, label %L1741
L1739:
  %r2274 = load i64, i64* @actor_budget
  %r2275 = load i64, i64* %ptr_i
  %r2276 = call i64 @_get(i64 %r2274, i64 %r2275)
  %r2277 = sub i64 %r2276, 1
  %r2278 = load i64, i64* %ptr_i
  %r2279 = load i64, i64* @actor_budget
  call i64 @_set(i64 %r2279, i64 %r2278, i64 %r2277)
  br label %L1741
L1741:
  br label %L1343
L1342:
  store i64 0, i64* %ptr_is_processing
  br label %L1343
L1343:
  br label %L1340
L1340:
  br label %L1335
L1337:
  br label %L1334
L1334:
  %r2280 = load i64, i64* %ptr_i
  %r2281 = call i64 @_add(i64 %r2280, i64 1)
  store i64 %r2281, i64* %ptr_i
  br label %L1329
L1331:
  ret i64 0
}
define i64 @init_mouse_advanced() {
  %ptr_status = alloca i64
  %ptr_id = alloca i64
  %r1 = call i64 @mouse_wait(i64 1)
  %r2 = trunc i64 100 to i16
  %r3 = trunc i64 168 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r3, i16 %r2)
  %r4 = call i64 @mouse_wait(i64 1)
  %r5 = trunc i64 100 to i16
  %r6 = trunc i64 32 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r6, i16 %r5)
  %r7 = call i64 @mouse_wait(i64 0)
  %r8 = trunc i64 96 to i16
  %r9 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r8)
  %r10 = zext i8 %r9 to i64
  %r11 = or i64 %r10, 2
  store i64 %r11, i64* %ptr_status
  %r12 = call i64 @mouse_wait(i64 1)
  %r13 = trunc i64 100 to i16
  %r14 = trunc i64 96 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r14, i16 %r13)
  %r15 = call i64 @mouse_wait(i64 1)
  %r16 = load i64, i64* %ptr_status
  %r17 = trunc i64 96 to i16
  %r18 = trunc i64 %r16 to i8
  call void asm sideeffect "outb %al, %dx", "{al},{dx},~{dirflag},~{fpsr},~{flags}"(i8 %r18, i16 %r17)
  %r19 = call i64 @mouse_write(i64 246)
  %r20 = call i64 @mouse_read()
  %r21 = call i64 @mouse_write(i64 243)
  %r22 = call i64 @mouse_read()
  %r23 = call i64 @mouse_write(i64 200)
  %r24 = call i64 @mouse_read()
  %r25 = call i64 @mouse_write(i64 243)
  %r26 = call i64 @mouse_read()
  %r27 = call i64 @mouse_write(i64 100)
  %r28 = call i64 @mouse_read()
  %r29 = call i64 @mouse_write(i64 243)
  %r30 = call i64 @mouse_read()
  %r31 = call i64 @mouse_write(i64 80)
  %r32 = call i64 @mouse_read()
  %r33 = call i64 @mouse_write(i64 242)
  %r34 = call i64 @mouse_read()
  %r35 = trunc i64 96 to i16
  %r36 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r35)
  %r37 = zext i8 %r36 to i64
  store i64 %r37, i64* %ptr_id
  %r38 = load i64, i64* %ptr_id
  %r39 = call i64 @_eq(i64 %r38, i64 3)
  %r40 = icmp ne i64 %r39, 0
  br i1 %r40, label %L1742, label %L1744
L1742:
  store i64 1, i64* @mouse_has_wheel
  br label %L1744
L1744:
  %r41 = call i64 @mouse_write(i64 244)
  %r42 = call i64 @mouse_read()
  ret i64 0
}
define i64 @achlys_main() {
  %ptr_running = alloca i64
  %ptr_needs_render = alloca i64
  %ptr_prev_l_down = alloca i64
  %ptr_prev_r_down = alloca i64
  %ptr_is_shifted = alloca i64
  %ptr_is_caps = alloca i64
  %ptr_status = alloca i64
  %ptr_byte1 = alloca i64
  %ptr_byte2 = alloca i64
  %ptr_byte3 = alloca i64
  %ptr_byte4 = alloca i64
  %ptr_rel_x = alloca i64
  %ptr_rel_y = alloca i64
  %ptr_z_delta = alloca i64
  %ptr_wx = alloca i64
  %ptr_wy = alloca i64
  %ptr_hover_node = alloca i64
  %ptr_hover_corner = alloca i64
  %ptr_exists = alloca i64
  %ptr_w = alloca i64
  %ptr_k_code = alloca i64
  %ptr_rel_code = alloca i64
  %ptr_limit = alloca i64
  %ptr_tries = alloca i64
  %ptr_slot = alloca i64
  %ptr_c = alloca i64
  %ptr_use_shift = alloca i64
  %ptr_is_letter = alloca i64
  %ptr_key_str = alloca i64
  %ptr_len = alloca i64
  %ptr_parts_active = alloca i64
  %r1 = call i64 @init_graphics()
  %r2 = call i64 @init_font()
  %r3 = call i64 @init_mouse_advanced()
  %r4 = call i64 @init_vfs()
  %r5 = call i64 @init_particles()
  store i64 1, i64* %ptr_running
  store i64 1, i64* %ptr_needs_render
  store i64 0, i64* %ptr_prev_l_down
  store i64 0, i64* %ptr_prev_r_down
  store i64 0, i64* %ptr_is_shifted
  store i64 0, i64* %ptr_is_caps
  br label %L1745
L1745:
  %r6 = load i64, i64* %ptr_running
  %r7 = icmp ne i64 %r6, 0
  br i1 %r7, label %L1746, label %L1747
L1746:
  %r8 = trunc i64 100 to i16
  %r9 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r8)
  %r10 = zext i8 %r9 to i64
  store i64 %r10, i64* %ptr_status
  %r11 = load i64, i64* %ptr_status
  %r12 = and i64 %r11, 1
  %r13 = call i64 @_eq(i64 %r12, i64 1)
  %r14 = icmp ne i64 %r13, 0
  br i1 %r14, label %L1748, label %L1749
L1748:
  %r15 = load i64, i64* %ptr_status
  %r16 = and i64 %r15, 32
  %r17 = call i64 @_eq(i64 %r16, i64 32)
  %r18 = icmp ne i64 %r17, 0
  br i1 %r18, label %L1751, label %L1752
L1751:
  %r19 = trunc i64 96 to i16
  %r20 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r19)
  %r21 = zext i8 %r20 to i64
  store i64 %r21, i64* %ptr_byte1
  %r22 = load i64, i64* %ptr_byte1
  %r23 = and i64 %r22, 8
  %r24 = call i64 @_eq(i64 %r23, i64 8)
  %r25 = icmp ne i64 %r24, 0
  br i1 %r25, label %L1754, label %L1756
L1754:
  %r26 = call i64 @mouse_wait(i64 0)
  %r27 = trunc i64 96 to i16
  %r28 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r27)
  %r29 = zext i8 %r28 to i64
  store i64 %r29, i64* %ptr_byte2
  %r30 = call i64 @mouse_wait(i64 0)
  %r31 = trunc i64 96 to i16
  %r32 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r31)
  %r33 = zext i8 %r32 to i64
  store i64 %r33, i64* %ptr_byte3
  store i64 0, i64* %ptr_byte4
  %r34 = load i64, i64* @mouse_has_wheel
  %r35 = icmp ne i64 %r34, 0
  br i1 %r35, label %L1757, label %L1759
L1757:
  %r36 = call i64 @mouse_wait(i64 0)
  %r37 = trunc i64 96 to i16
  %r38 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r37)
  %r39 = zext i8 %r38 to i64
  store i64 %r39, i64* %ptr_byte4
  br label %L1759
L1759:
  %r40 = load i64, i64* %ptr_byte2
  store i64 %r40, i64* %ptr_rel_x
  %r41 = load i64, i64* %ptr_byte3
  store i64 %r41, i64* %ptr_rel_y
  %r42 = load i64, i64* %ptr_byte1
  %r43 = and i64 %r42, 16
  %r44 = icmp ne i64 %r43, 0
  br i1 %r44, label %L1760, label %L1762
L1760:
  %r45 = load i64, i64* %ptr_rel_x
  %r46 = or i64 %r45, -256
  store i64 %r46, i64* %ptr_rel_x
  br label %L1762
L1762:
  %r47 = load i64, i64* %ptr_byte1
  %r48 = and i64 %r47, 32
  %r49 = icmp ne i64 %r48, 0
  br i1 %r49, label %L1763, label %L1765
L1763:
  %r50 = load i64, i64* %ptr_rel_y
  %r51 = or i64 %r50, -256
  store i64 %r51, i64* %ptr_rel_y
  br label %L1765
L1765:
  %r52 = load i64, i64* @mouse_x
  %r53 = load i64, i64* %ptr_rel_x
  %r54 = call i64 @_add(i64 %r52, i64 %r53)
  store i64 %r54, i64* @mouse_x
  %r55 = load i64, i64* @mouse_y
  %r56 = load i64, i64* %ptr_rel_y
  %r57 = sub i64 %r55, %r56
  store i64 %r57, i64* @mouse_y
  %r58 = load i64, i64* @mouse_x
  %r60 = icmp slt i64 %r58, 0
  %r59 = zext i1 %r60 to i64
  %r61 = icmp ne i64 %r59, 0
  br i1 %r61, label %L1766, label %L1768
L1766:
  store i64 0, i64* @mouse_x
  br label %L1768
L1768:
  %r62 = load i64, i64* @mouse_x
  %r63 = load i64, i64* @FB_WIDTH
  %r65 = icmp sge i64 %r62, %r63
  %r64 = zext i1 %r65 to i64
  %r66 = icmp ne i64 %r64, 0
  br i1 %r66, label %L1769, label %L1771
L1769:
  %r67 = load i64, i64* @FB_WIDTH
  %r68 = sub i64 %r67, 1
  store i64 %r68, i64* @mouse_x
  br label %L1771
L1771:
  %r69 = load i64, i64* @mouse_y
  %r71 = icmp slt i64 %r69, 0
  %r70 = zext i1 %r71 to i64
  %r72 = icmp ne i64 %r70, 0
  br i1 %r72, label %L1772, label %L1774
L1772:
  store i64 0, i64* @mouse_y
  br label %L1774
L1774:
  %r73 = load i64, i64* @mouse_y
  %r74 = load i64, i64* @FB_HEIGHT
  %r76 = icmp sge i64 %r73, %r74
  %r75 = zext i1 %r76 to i64
  %r77 = icmp ne i64 %r75, 0
  br i1 %r77, label %L1775, label %L1777
L1775:
  %r78 = load i64, i64* @FB_HEIGHT
  %r79 = sub i64 %r78, 1
  store i64 %r79, i64* @mouse_y
  br label %L1777
L1777:
  %r80 = load i64, i64* @paradigm
  %r81 = call i64 @_eq(i64 %r80, i64 0)
  store i64 0, i64* @.sc.552
  %r83 = icmp ne i64 %r81, 0
  br i1 %r83, label %L1778, label %L1779
L1778:
  %r84 = load i64, i64* %ptr_byte4
  %r86 = call i64 @_eq(i64 %r84, i64 0)
  %r85 = xor i64 %r86, 1
  %r87 = icmp ne i64 %r85, 0
  %r88 = zext i1 %r87 to i64
  store i64 %r88, i64* @.sc.552
  br label %L1779
L1779:
  %r82 = load i64, i64* @.sc.552
  %r89 = icmp ne i64 %r82, 0
  br i1 %r89, label %L1780, label %L1782
L1780:
  %r90 = load i64, i64* %ptr_byte4
  store i64 %r90, i64* %ptr_z_delta
  %r91 = load i64, i64* %ptr_z_delta
  %r93 = icmp sgt i64 %r91, 127
  %r92 = zext i1 %r93 to i64
  %r94 = icmp ne i64 %r92, 0
  br i1 %r94, label %L1783, label %L1785
L1783:
  %r95 = load i64, i64* %ptr_z_delta
  %r96 = sub i64 %r95, 256
  store i64 %r96, i64* %ptr_z_delta
  br label %L1785
L1785:
  %r97 = load i64, i64* @cam_z
  %r98 = load i64, i64* %ptr_z_delta
  %r99 = mul i64 %r98, 10
  %r100 = sub i64 %r97, %r99
  store i64 %r100, i64* @cam_z
  %r101 = load i64, i64* @cam_z
  %r103 = icmp slt i64 %r101, 10
  %r102 = zext i1 %r103 to i64
  %r104 = icmp ne i64 %r102, 0
  br i1 %r104, label %L1786, label %L1788
L1786:
  store i64 10, i64* @cam_z
  br label %L1788
L1788:
  br label %L1782
L1782:
  %r105 = load i64, i64* %ptr_byte1
  %r106 = and i64 %r105, 1
  store i64 %r106, i64* @mouse_l_down
  %r107 = load i64, i64* %ptr_byte1
  %r108 = lshr i64 %r107, 1
  %r109 = and i64 %r108, 1
  store i64 %r109, i64* @mouse_r_down
  %r110 = load i64, i64* @mouse_x
  %r111 = call i64 @screen_to_world_x(i64 %r110)
  store i64 %r111, i64* %ptr_wx
  %r112 = load i64, i64* @mouse_y
  %r113 = call i64 @screen_to_world_y(i64 %r112)
  store i64 %r113, i64* %ptr_wy
  %r114 = load i64, i64* %ptr_wx
  %r115 = load i64, i64* %ptr_wy
  %r116 = call i64 @get_hovered_node(i64 %r114, i64 %r115)
  store i64 %r116, i64* %ptr_hover_node
  %r117 = load i64, i64* %ptr_wx
  %r118 = load i64, i64* %ptr_wy
  %r119 = call i64 @get_hovered_corner(i64 %r117, i64 %r118)
  store i64 %r119, i64* %ptr_hover_corner
  %r120 = load i64, i64* @mouse_l_down
  store i64 0, i64* @.sc.553
  %r122 = icmp ne i64 %r120, 0
  br i1 %r122, label %L1789, label %L1790
L1789:
  %r123 = load i64, i64* %ptr_prev_l_down
  %r124 = call i64 @_eq(i64 %r123, i64 0)
  %r125 = icmp ne i64 %r124, 0
  %r126 = zext i1 %r125 to i64
  store i64 %r126, i64* @.sc.553
  br label %L1790
L1790:
  %r121 = load i64, i64* @.sc.553
  %r127 = icmp ne i64 %r121, 0
  br i1 %r127, label %L1791, label %L1793
L1791:
  %r128 = load i64, i64* %ptr_hover_node
  %r129 = sub i64 0, 1
  %r130 = call i64 @_eq(i64 %r128, i64 %r129)
  store i64 0, i64* @.sc.554
  %r132 = icmp ne i64 %r130, 0
  br i1 %r132, label %L1794, label %L1795
L1794:
  %r133 = load i64, i64* %ptr_hover_corner
  %r134 = sub i64 0, 1
  %r135 = call i64 @_eq(i64 %r133, i64 %r134)
  %r136 = icmp ne i64 %r135, 0
  %r137 = zext i1 %r136 to i64
  store i64 %r137, i64* @.sc.554
  br label %L1795
L1795:
  %r131 = load i64, i64* @.sc.554
  %r138 = icmp ne i64 %r131, 0
  br i1 %r138, label %L1796, label %L1797
L1796:
  %r139 = sub i64 0, 1
  store i64 %r139, i64* @focused_node
  br label %L1798
L1797:
  %r140 = load i64, i64* @paradigm
  %r141 = call i64 @_eq(i64 %r140, i64 0)
  store i64 0, i64* @.sc.555
  %r143 = icmp ne i64 %r141, 0
  br i1 %r143, label %L1799, label %L1800
L1799:
  %r144 = load i64, i64* %ptr_hover_corner
  %r145 = sub i64 0, 1
  %r147 = call i64 @_eq(i64 %r144, i64 %r145)
  %r146 = xor i64 %r147, 1
  %r148 = icmp ne i64 %r146, 0
  %r149 = zext i1 %r148 to i64
  store i64 %r149, i64* @.sc.555
  br label %L1800
L1800:
  %r142 = load i64, i64* @.sc.555
  %r150 = icmp ne i64 %r142, 0
  br i1 %r150, label %L1801, label %L1802
L1801:
  %r151 = load i64, i64* %ptr_hover_corner
  store i64 %r151, i64* @resizing_node
  %r152 = load i64, i64* %ptr_hover_corner
  store i64 %r152, i64* @focused_node
  br label %L1803
L1802:
  %r153 = load i64, i64* %ptr_hover_node
  store i64 %r153, i64* @focused_node
  br label %L1803
L1803:
  br label %L1798
L1798:
  %r154 = load i64, i64* @routing_node
  %r155 = sub i64 0, 1
  %r157 = call i64 @_eq(i64 %r154, i64 %r155)
  %r156 = xor i64 %r157, 1
  %r158 = icmp ne i64 %r156, 0
  br i1 %r158, label %L1804, label %L1805
L1804:
  %r159 = load i64, i64* %ptr_hover_node
  %r160 = sub i64 0, 1
  %r162 = call i64 @_eq(i64 %r159, i64 %r160)
  %r161 = xor i64 %r162, 1
  store i64 0, i64* @.sc.556
  %r164 = icmp ne i64 %r161, 0
  br i1 %r164, label %L1807, label %L1808
L1807:
  %r165 = load i64, i64* %ptr_hover_node
  %r166 = load i64, i64* @routing_node
  %r168 = call i64 @_eq(i64 %r165, i64 %r166)
  %r167 = xor i64 %r168, 1
  %r169 = icmp ne i64 %r167, 0
  %r170 = zext i1 %r169 to i64
  store i64 %r170, i64* @.sc.556
  br label %L1808
L1808:
  %r163 = load i64, i64* @.sc.556
  %r171 = icmp ne i64 %r163, 0
  br i1 %r171, label %L1809, label %L1811
L1809:
  %r172 = sub i64 0, 1
  store i64 %r172, i64* %ptr_exists
  store i64 0, i64* %ptr_w
  br label %L1812
L1812:
  %r173 = load i64, i64* %ptr_w
  %r174 = load i64, i64* @wire_from
  %r175 = call i64 @mensura(i64 %r174)
  %r177 = icmp slt i64 %r173, %r175
  %r176 = zext i1 %r177 to i64
  %r178 = icmp ne i64 %r176, 0
  br i1 %r178, label %L1813, label %L1814
L1813:
  %r179 = load i64, i64* @wire_from
  %r180 = load i64, i64* %ptr_w
  %r181 = call i64 @_get(i64 %r179, i64 %r180)
  %r182 = load i64, i64* @routing_node
  %r183 = call i64 @_eq(i64 %r181, i64 %r182)
  store i64 0, i64* @.sc.557
  %r185 = icmp ne i64 %r183, 0
  br i1 %r185, label %L1815, label %L1816
L1815:
  %r186 = load i64, i64* @wire_to
  %r187 = load i64, i64* %ptr_w
  %r188 = call i64 @_get(i64 %r186, i64 %r187)
  %r189 = load i64, i64* %ptr_hover_node
  %r190 = call i64 @_eq(i64 %r188, i64 %r189)
  %r191 = icmp ne i64 %r190, 0
  %r192 = zext i1 %r191 to i64
  store i64 %r192, i64* @.sc.557
  br label %L1816
L1816:
  %r184 = load i64, i64* @.sc.557
  %r193 = icmp ne i64 %r184, 0
  br i1 %r193, label %L1817, label %L1819
L1817:
  %r194 = load i64, i64* %ptr_w
  store i64 %r194, i64* %ptr_exists
  br label %L1819
L1819:
  %r195 = load i64, i64* %ptr_w
  %r196 = call i64 @_add(i64 %r195, i64 1)
  store i64 %r196, i64* %ptr_w
  br label %L1812
L1814:
  %r197 = load i64, i64* %ptr_exists
  %r198 = sub i64 0, 1
  %r200 = call i64 @_eq(i64 %r197, i64 %r198)
  %r199 = xor i64 %r200, 1
  %r201 = icmp ne i64 %r199, 0
  br i1 %r201, label %L1820, label %L1821
L1820:
  %r202 = load i64, i64* %ptr_exists
  %r203 = call i64 @remove_wire(i64 %r202)
  br label %L1822
L1821:
  %r204 = load i64, i64* @routing_node
  %r205 = load i64, i64* @wire_from
  call i64 @_append_poly(i64 %r205, i64 %r204)
  %r206 = load i64, i64* %ptr_hover_node
  %r207 = load i64, i64* @wire_to
  call i64 @_append_poly(i64 %r207, i64 %r206)
  br label %L1822
L1822:
  br label %L1811
L1811:
  %r208 = sub i64 0, 1
  store i64 %r208, i64* @routing_node
  br label %L1806
L1805:
  %r209 = load i64, i64* %ptr_hover_corner
  %r210 = sub i64 0, 1
  %r211 = call i64 @_eq(i64 %r209, i64 %r210)
  %r212 = icmp ne i64 %r211, 0
  br i1 %r212, label %L1823, label %L1825
L1823:
  %r213 = load i64, i64* %ptr_hover_node
  store i64 %r213, i64* @grabbed_node
  br label %L1825
L1825:
  br label %L1806
L1806:
  br label %L1793
L1793:
  %r214 = load i64, i64* @mouse_r_down
  store i64 0, i64* @.sc.558
  %r216 = icmp ne i64 %r214, 0
  br i1 %r216, label %L1826, label %L1827
L1826:
  %r217 = load i64, i64* %ptr_prev_r_down
  %r218 = call i64 @_eq(i64 %r217, i64 0)
  %r219 = icmp ne i64 %r218, 0
  %r220 = zext i1 %r219 to i64
  store i64 %r220, i64* @.sc.558
  br label %L1827
L1827:
  %r215 = load i64, i64* @.sc.558
  %r221 = icmp ne i64 %r215, 0
  br i1 %r221, label %L1828, label %L1830
L1828:
  %r222 = load i64, i64* @routing_node
  %r223 = sub i64 0, 1
  %r224 = call i64 @_eq(i64 %r222, i64 %r223)
  %r225 = icmp ne i64 %r224, 0
  br i1 %r225, label %L1831, label %L1832
L1831:
  %r226 = load i64, i64* %ptr_hover_node
  %r227 = sub i64 0, 1
  %r229 = call i64 @_eq(i64 %r226, i64 %r227)
  %r228 = xor i64 %r229, 1
  %r230 = icmp ne i64 %r228, 0
  br i1 %r230, label %L1834, label %L1836
L1834:
  %r231 = load i64, i64* %ptr_hover_node
  store i64 %r231, i64* @routing_node
  br label %L1836
L1836:
  br label %L1833
L1832:
  %r232 = sub i64 0, 1
  store i64 %r232, i64* @routing_node
  br label %L1833
L1833:
  br label %L1830
L1830:
  %r233 = load i64, i64* @mouse_l_down
  %r234 = call i64 @_eq(i64 %r233, i64 0)
  %r235 = icmp ne i64 %r234, 0
  br i1 %r235, label %L1837, label %L1839
L1837:
  %r236 = sub i64 0, 1
  store i64 %r236, i64* @grabbed_node
  %r237 = sub i64 0, 1
  store i64 %r237, i64* @resizing_node
  br label %L1839
L1839:
  %r238 = load i64, i64* @paradigm
  %r239 = call i64 @_eq(i64 %r238, i64 0)
  store i64 0, i64* @.sc.560
  %r241 = icmp ne i64 %r239, 0
  br i1 %r241, label %L1840, label %L1841
L1840:
  %r242 = load i64, i64* @mouse_l_down
  %r243 = icmp ne i64 %r242, 0
  %r244 = zext i1 %r243 to i64
  store i64 %r244, i64* @.sc.560
  br label %L1841
L1841:
  %r240 = load i64, i64* @.sc.560
  store i64 0, i64* @.sc.559
  %r246 = icmp ne i64 %r240, 0
  br i1 %r246, label %L1842, label %L1843
L1842:
  %r247 = load i64, i64* @resizing_node
  %r248 = sub i64 0, 1
  %r250 = call i64 @_eq(i64 %r247, i64 %r248)
  %r249 = xor i64 %r250, 1
  %r251 = icmp ne i64 %r249, 0
  %r252 = zext i1 %r251 to i64
  store i64 %r252, i64* @.sc.559
  br label %L1843
L1843:
  %r245 = load i64, i64* @.sc.559
  %r253 = icmp ne i64 %r245, 0
  br i1 %r253, label %L1844, label %L1845
L1844:
  %r254 = load i64, i64* @actor_w
  %r255 = load i64, i64* @resizing_node
  %r256 = call i64 @_get(i64 %r254, i64 %r255)
  %r257 = load i64, i64* %ptr_rel_x
  %r258 = mul i64 %r257, 100
  %r259 = load i64, i64* @cam_z
  %r260 = sdiv i64 %r258, %r259
  %r261 = call i64 @_add(i64 %r256, i64 %r260)
  %r262 = load i64, i64* @resizing_node
  %r263 = load i64, i64* @actor_w
  call i64 @_set(i64 %r263, i64 %r262, i64 %r261)
  %r264 = load i64, i64* @actor_h
  %r265 = load i64, i64* @resizing_node
  %r266 = call i64 @_get(i64 %r264, i64 %r265)
  %r267 = load i64, i64* %ptr_rel_y
  %r268 = mul i64 %r267, 100
  %r269 = load i64, i64* @cam_z
  %r270 = sdiv i64 %r268, %r269
  %r271 = sub i64 %r266, %r270
  %r272 = load i64, i64* @resizing_node
  %r273 = load i64, i64* @actor_h
  call i64 @_set(i64 %r273, i64 %r272, i64 %r271)
  %r274 = load i64, i64* @actor_w
  %r275 = load i64, i64* @resizing_node
  %r276 = call i64 @_get(i64 %r274, i64 %r275)
  %r278 = icmp slt i64 %r276, 100
  %r277 = zext i1 %r278 to i64
  %r279 = icmp ne i64 %r277, 0
  br i1 %r279, label %L1847, label %L1849
L1847:
  %r280 = load i64, i64* @resizing_node
  %r281 = load i64, i64* @actor_w
  call i64 @_set(i64 %r281, i64 %r280, i64 100)
  br label %L1849
L1849:
  %r282 = load i64, i64* @actor_h
  %r283 = load i64, i64* @resizing_node
  %r284 = call i64 @_get(i64 %r282, i64 %r283)
  %r286 = icmp slt i64 %r284, 50
  %r285 = zext i1 %r286 to i64
  %r287 = icmp ne i64 %r285, 0
  br i1 %r287, label %L1850, label %L1852
L1850:
  %r288 = load i64, i64* @resizing_node
  %r289 = load i64, i64* @actor_h
  call i64 @_set(i64 %r289, i64 %r288, i64 50)
  br label %L1852
L1852:
  br label %L1846
L1845:
  %r290 = load i64, i64* @paradigm
  %r291 = call i64 @_eq(i64 %r290, i64 0)
  store i64 0, i64* @.sc.562
  %r293 = icmp ne i64 %r291, 0
  br i1 %r293, label %L1853, label %L1854
L1853:
  %r294 = load i64, i64* @mouse_l_down
  %r295 = icmp ne i64 %r294, 0
  %r296 = zext i1 %r295 to i64
  store i64 %r296, i64* @.sc.562
  br label %L1854
L1854:
  %r292 = load i64, i64* @.sc.562
  store i64 0, i64* @.sc.561
  %r298 = icmp ne i64 %r292, 0
  br i1 %r298, label %L1855, label %L1856
L1855:
  %r299 = load i64, i64* @grabbed_node
  %r300 = sub i64 0, 1
  %r302 = call i64 @_eq(i64 %r299, i64 %r300)
  %r301 = xor i64 %r302, 1
  %r303 = icmp ne i64 %r301, 0
  %r304 = zext i1 %r303 to i64
  store i64 %r304, i64* @.sc.561
  br label %L1856
L1856:
  %r297 = load i64, i64* @.sc.561
  %r305 = icmp ne i64 %r297, 0
  br i1 %r305, label %L1857, label %L1858
L1857:
  %r306 = load i64, i64* @actor_x
  %r307 = load i64, i64* @grabbed_node
  %r308 = call i64 @_get(i64 %r306, i64 %r307)
  %r309 = load i64, i64* %ptr_rel_x
  %r310 = mul i64 %r309, 100
  %r311 = load i64, i64* @cam_z
  %r312 = sdiv i64 %r310, %r311
  %r313 = call i64 @_add(i64 %r308, i64 %r312)
  %r314 = load i64, i64* @grabbed_node
  %r315 = load i64, i64* @actor_x
  call i64 @_set(i64 %r315, i64 %r314, i64 %r313)
  %r316 = load i64, i64* @actor_y
  %r317 = load i64, i64* @grabbed_node
  %r318 = call i64 @_get(i64 %r316, i64 %r317)
  %r319 = load i64, i64* %ptr_rel_y
  %r320 = mul i64 %r319, 100
  %r321 = load i64, i64* @cam_z
  %r322 = sdiv i64 %r320, %r321
  %r323 = sub i64 %r318, %r322
  %r324 = load i64, i64* @grabbed_node
  %r325 = load i64, i64* @actor_y
  call i64 @_set(i64 %r325, i64 %r324, i64 %r323)
  br label %L1859
L1858:
  %r326 = load i64, i64* @paradigm
  %r327 = call i64 @_eq(i64 %r326, i64 0)
  store i64 0, i64* @.sc.565
  %r329 = icmp ne i64 %r327, 0
  br i1 %r329, label %L1860, label %L1861
L1860:
  %r330 = load i64, i64* @mouse_l_down
  %r331 = icmp ne i64 %r330, 0
  %r332 = zext i1 %r331 to i64
  store i64 %r332, i64* @.sc.565
  br label %L1861
L1861:
  %r328 = load i64, i64* @.sc.565
  store i64 0, i64* @.sc.564
  %r334 = icmp ne i64 %r328, 0
  br i1 %r334, label %L1862, label %L1863
L1862:
  %r335 = load i64, i64* @grabbed_node
  %r336 = sub i64 0, 1
  %r337 = call i64 @_eq(i64 %r335, i64 %r336)
  %r338 = icmp ne i64 %r337, 0
  %r339 = zext i1 %r338 to i64
  store i64 %r339, i64* @.sc.564
  br label %L1863
L1863:
  %r333 = load i64, i64* @.sc.564
  store i64 0, i64* @.sc.563
  %r341 = icmp ne i64 %r333, 0
  br i1 %r341, label %L1864, label %L1865
L1864:
  %r342 = load i64, i64* @routing_node
  %r343 = sub i64 0, 1
  %r344 = call i64 @_eq(i64 %r342, i64 %r343)
  %r345 = icmp ne i64 %r344, 0
  %r346 = zext i1 %r345 to i64
  store i64 %r346, i64* @.sc.563
  br label %L1865
L1865:
  %r340 = load i64, i64* @.sc.563
  %r347 = icmp ne i64 %r340, 0
  br i1 %r347, label %L1866, label %L1868
L1866:
  %r348 = load i64, i64* @cam_x
  %r349 = load i64, i64* %ptr_rel_x
  %r350 = mul i64 %r349, 100
  %r351 = load i64, i64* @cam_z
  %r352 = sdiv i64 %r350, %r351
  %r353 = sub i64 %r348, %r352
  store i64 %r353, i64* @cam_x
  %r354 = load i64, i64* @cam_y
  %r355 = load i64, i64* %ptr_rel_y
  %r356 = mul i64 %r355, 100
  %r357 = load i64, i64* @cam_z
  %r358 = sdiv i64 %r356, %r357
  %r359 = call i64 @_add(i64 %r354, i64 %r358)
  store i64 %r359, i64* @cam_y
  br label %L1868
L1868:
  br label %L1859
L1859:
  br label %L1846
L1846:
  %r360 = load i64, i64* @mouse_l_down
  store i64 %r360, i64* %ptr_prev_l_down
  %r361 = load i64, i64* @mouse_r_down
  store i64 %r361, i64* %ptr_prev_r_down
  store i64 1, i64* %ptr_needs_render
  br label %L1756
L1756:
  br label %L1753
L1752:
  %r362 = trunc i64 96 to i16
  %r363 = call i8 asm sideeffect "inb %dx, %al", "={al},{dx},~{dirflag},~{fpsr},~{flags}"(i16 %r362)
  %r364 = zext i8 %r363 to i64
  store i64 %r364, i64* %ptr_k_code
  %r365 = load i64, i64* %ptr_k_code
  %r367 = icmp sge i64 %r365, 128
  %r366 = zext i1 %r367 to i64
  %r368 = icmp ne i64 %r366, 0
  br i1 %r368, label %L1869, label %L1870
L1869:
  %r369 = load i64, i64* %ptr_k_code
  %r370 = sub i64 %r369, 128
  store i64 %r370, i64* %ptr_rel_code
  %r371 = load i64, i64* %ptr_rel_code
  %r372 = call i64 @_eq(i64 %r371, i64 42)
  store i64 1, i64* @.sc.566
  %r374 = icmp eq i64 %r372, 0
  br i1 %r374, label %L1872, label %L1873
L1872:
  %r375 = load i64, i64* %ptr_rel_code
  %r376 = call i64 @_eq(i64 %r375, i64 54)
  %r377 = icmp ne i64 %r376, 0
  %r378 = zext i1 %r377 to i64
  store i64 %r378, i64* @.sc.566
  br label %L1873
L1873:
  %r373 = load i64, i64* @.sc.566
  %r379 = icmp ne i64 %r373, 0
  br i1 %r379, label %L1874, label %L1876
L1874:
  store i64 0, i64* %ptr_is_shifted
  br label %L1876
L1876:
  br label %L1871
L1870:
  %r380 = load i64, i64* %ptr_k_code
  %r381 = call i64 @_eq(i64 %r380, i64 42)
  store i64 1, i64* @.sc.567
  %r383 = icmp eq i64 %r381, 0
  br i1 %r383, label %L1877, label %L1878
L1877:
  %r384 = load i64, i64* %ptr_k_code
  %r385 = call i64 @_eq(i64 %r384, i64 54)
  %r386 = icmp ne i64 %r385, 0
  %r387 = zext i1 %r386 to i64
  store i64 %r387, i64* @.sc.567
  br label %L1878
L1878:
  %r382 = load i64, i64* @.sc.567
  %r388 = icmp ne i64 %r382, 0
  br i1 %r388, label %L1879, label %L1880
L1879:
  store i64 1, i64* %ptr_is_shifted
  br label %L1881
L1880:
  %r389 = load i64, i64* %ptr_k_code
  %r390 = call i64 @_eq(i64 %r389, i64 58)
  %r391 = icmp ne i64 %r390, 0
  br i1 %r391, label %L1882, label %L1883
L1882:
  %r392 = load i64, i64* %ptr_is_caps
  %r393 = call i64 @_eq(i64 %r392, i64 1)
  %r394 = icmp ne i64 %r393, 0
  br i1 %r394, label %L1885, label %L1886
L1885:
  store i64 0, i64* %ptr_is_caps
  br label %L1887
L1886:
  store i64 1, i64* %ptr_is_caps
  br label %L1887
L1887:
  br label %L1884
L1883:
  %r395 = load i64, i64* %ptr_k_code
  %r396 = call i64 @_eq(i64 %r395, i64 15)
  store i64 0, i64* @.sc.568
  %r398 = icmp ne i64 %r396, 0
  br i1 %r398, label %L1888, label %L1889
L1888:
  %r399 = load i64, i64* @actor_x
  %r400 = call i64 @mensura(i64 %r399)
  %r402 = icmp sgt i64 %r400, 0
  %r401 = zext i1 %r402 to i64
  %r403 = icmp ne i64 %r401, 0
  %r404 = zext i1 %r403 to i64
  store i64 %r404, i64* @.sc.568
  br label %L1889
L1889:
  %r397 = load i64, i64* @.sc.568
  %r405 = icmp ne i64 %r397, 0
  br i1 %r405, label %L1890, label %L1891
L1890:
  %r406 = load i64, i64* @actor_x
  %r407 = call i64 @mensura(i64 %r406)
  store i64 %r407, i64* %ptr_limit
  store i64 0, i64* %ptr_tries
  br label %L1893
L1893:
  %r408 = load i64, i64* %ptr_tries
  %r409 = load i64, i64* %ptr_limit
  %r411 = icmp slt i64 %r408, %r409
  %r410 = zext i1 %r411 to i64
  %r412 = icmp ne i64 %r410, 0
  br i1 %r412, label %L1894, label %L1895
L1894:
  %r413 = load i64, i64* @focused_node
  %r414 = call i64 @_add(i64 %r413, i64 1)
  %r415 = load i64, i64* @actor_x
  %r416 = call i64 @mensura(i64 %r415)
  %r417 = srem i64 %r414, %r416
  store i64 %r417, i64* @focused_node
  %r418 = load i64, i64* @actor_app
  %r419 = load i64, i64* @focused_node
  %r420 = call i64 @_get(i64 %r418, i64 %r419)
  %r421 = sub i64 0, 1
  %r423 = call i64 @_eq(i64 %r420, i64 %r421)
  %r422 = xor i64 %r423, 1
  %r424 = icmp ne i64 %r422, 0
  br i1 %r424, label %L1896, label %L1898
L1896:
  %r425 = load i64, i64* %ptr_limit
  store i64 %r425, i64* %ptr_tries
  br label %L1898
L1898:
  %r426 = load i64, i64* %ptr_tries
  %r427 = call i64 @_add(i64 %r426, i64 1)
  store i64 %r427, i64* %ptr_tries
  br label %L1893
L1895:
  store i64 1, i64* %ptr_needs_render
  br label %L1892
L1891:
  %r428 = load i64, i64* %ptr_k_code
  %r429 = call i64 @_eq(i64 %r428, i64 60)
  %r430 = icmp ne i64 %r429, 0
  br i1 %r430, label %L1899, label %L1900
L1899:
  %r431 = sub i64 0, 1
  store i64 %r431, i64* %ptr_slot
  store i64 0, i64* %ptr_c
  br label %L1902
L1902:
  %r432 = load i64, i64* %ptr_c
  %r433 = load i64, i64* @actor_x
  %r434 = call i64 @mensura(i64 %r433)
  %r436 = icmp slt i64 %r432, %r434
  %r435 = zext i1 %r436 to i64
  %r437 = icmp ne i64 %r435, 0
  br i1 %r437, label %L1903, label %L1904
L1903:
  %r438 = load i64, i64* @actor_app
  %r439 = load i64, i64* %ptr_c
  %r440 = call i64 @_get(i64 %r438, i64 %r439)
  %r441 = sub i64 0, 1
  %r442 = call i64 @_eq(i64 %r440, i64 %r441)
  store i64 0, i64* @.sc.569
  %r444 = icmp ne i64 %r442, 0
  br i1 %r444, label %L1905, label %L1906
L1905:
  %r445 = load i64, i64* %ptr_slot
  %r446 = sub i64 0, 1
  %r447 = call i64 @_eq(i64 %r445, i64 %r446)
  %r448 = icmp ne i64 %r447, 0
  %r449 = zext i1 %r448 to i64
  store i64 %r449, i64* @.sc.569
  br label %L1906
L1906:
  %r443 = load i64, i64* @.sc.569
  %r450 = icmp ne i64 %r443, 0
  br i1 %r450, label %L1907, label %L1909
L1907:
  %r451 = load i64, i64* %ptr_c
  store i64 %r451, i64* %ptr_slot
  br label %L1909
L1909:
  %r452 = load i64, i64* %ptr_c
  %r453 = call i64 @_add(i64 %r452, i64 1)
  store i64 %r453, i64* %ptr_c
  br label %L1902
L1904:
  %r454 = load i64, i64* %ptr_slot
  %r455 = sub i64 0, 1
  %r457 = call i64 @_eq(i64 %r454, i64 %r455)
  %r456 = xor i64 %r457, 1
  %r458 = icmp ne i64 %r456, 0
  br i1 %r458, label %L1910, label %L1911
L1910:
  %r459 = load i64, i64* @cam_x
  %r460 = call i64 @_add(i64 %r459, i64 100)
  %r461 = load i64, i64* %ptr_slot
  %r462 = load i64, i64* @actor_x
  call i64 @_set(i64 %r462, i64 %r461, i64 %r460)
  %r463 = load i64, i64* @cam_y
  %r464 = call i64 @_add(i64 %r463, i64 100)
  %r465 = load i64, i64* %ptr_slot
  %r466 = load i64, i64* @actor_y
  call i64 @_set(i64 %r466, i64 %r465, i64 %r464)
  %r467 = load i64, i64* %ptr_slot
  %r468 = load i64, i64* @actor_w
  call i64 @_set(i64 %r468, i64 %r467, i64 400)
  %r469 = load i64, i64* %ptr_slot
  %r470 = load i64, i64* @actor_h
  call i64 @_set(i64 %r470, i64 %r469, i64 300)
  %r471 = getelementptr [31 x i8], [31 x i8]* @.str.570, i64 0, i64 0
  %r472 = ptrtoint i8* %r471 to i64
  %r473 = load i64, i64* %ptr_slot
  %r474 = load i64, i64* @actor_text
  call i64 @_set(i64 %r474, i64 %r473, i64 %r472)
  %r475 = getelementptr [1 x i8], [1 x i8]* @.str.571, i64 0, i64 0
  %r476 = ptrtoint i8* %r475 to i64
  %r477 = load i64, i64* %ptr_slot
  %r478 = load i64, i64* @actor_cmd
  call i64 @_set(i64 %r478, i64 %r477, i64 %r476)
  %r479 = getelementptr [1 x i8], [1 x i8]* @.str.572, i64 0, i64 0
  %r480 = ptrtoint i8* %r479 to i64
  %r481 = load i64, i64* %ptr_slot
  %r482 = load i64, i64* @actor_mailbox
  call i64 @_set(i64 %r482, i64 %r481, i64 %r480)
  %r483 = load i64, i64* %ptr_slot
  %r484 = load i64, i64* @actor_budget
  call i64 @_set(i64 %r484, i64 %r483, i64 0)
  %r485 = load i64, i64* %ptr_slot
  %r486 = load i64, i64* @actor_app
  call i64 @_set(i64 %r486, i64 %r485, i64 0)
  %r487 = getelementptr [1 x i8], [1 x i8]* @.str.573, i64 0, i64 0
  %r488 = ptrtoint i8* %r487 to i64
  %r489 = load i64, i64* %ptr_slot
  %r490 = load i64, i64* @actor_file_buf
  call i64 @_set(i64 %r490, i64 %r489, i64 %r488)
  %r491 = getelementptr [1 x i8], [1 x i8]* @.str.574, i64 0, i64 0
  %r492 = ptrtoint i8* %r491 to i64
  %r493 = load i64, i64* %ptr_slot
  %r494 = load i64, i64* @actor_target
  call i64 @_set(i64 %r494, i64 %r493, i64 %r492)
  %r495 = load i64, i64* @paradigm
  %r496 = call i64 @_eq(i64 %r495, i64 1)
  %r497 = icmp ne i64 %r496, 0
  br i1 %r497, label %L1913, label %L1915
L1913:
  %r498 = call i64 @apply_layout()
  br label %L1915
L1915:
  %r499 = load i64, i64* %ptr_slot
  store i64 %r499, i64* @focused_node
  br label %L1912
L1911:
  %r500 = load i64, i64* @cam_x
  %r501 = call i64 @_add(i64 %r500, i64 100)
  %r502 = load i64, i64* @actor_x
  call i64 @_append_poly(i64 %r502, i64 %r501)
  %r503 = load i64, i64* @cam_y
  %r504 = call i64 @_add(i64 %r503, i64 100)
  %r505 = load i64, i64* @actor_y
  call i64 @_append_poly(i64 %r505, i64 %r504)
  %r506 = load i64, i64* @actor_w
  call i64 @_append_poly(i64 %r506, i64 400)
  %r507 = load i64, i64* @actor_h
  call i64 @_append_poly(i64 %r507, i64 300)
  %r508 = getelementptr [31 x i8], [31 x i8]* @.str.575, i64 0, i64 0
  %r509 = ptrtoint i8* %r508 to i64
  %r510 = load i64, i64* @actor_text
  call i64 @_append_poly(i64 %r510, i64 %r509)
  %r511 = getelementptr [1 x i8], [1 x i8]* @.str.576, i64 0, i64 0
  %r512 = ptrtoint i8* %r511 to i64
  %r513 = load i64, i64* @actor_cmd
  call i64 @_append_poly(i64 %r513, i64 %r512)
  %r514 = getelementptr [1 x i8], [1 x i8]* @.str.577, i64 0, i64 0
  %r515 = ptrtoint i8* %r514 to i64
  %r516 = load i64, i64* @actor_mailbox
  call i64 @_append_poly(i64 %r516, i64 %r515)
  %r517 = load i64, i64* @actor_budget
  call i64 @_append_poly(i64 %r517, i64 0)
  %r518 = load i64, i64* @actor_app
  call i64 @_append_poly(i64 %r518, i64 0)
  %r519 = getelementptr [1 x i8], [1 x i8]* @.str.578, i64 0, i64 0
  %r520 = ptrtoint i8* %r519 to i64
  %r521 = load i64, i64* @actor_file_buf
  call i64 @_append_poly(i64 %r521, i64 %r520)
  %r522 = getelementptr [1 x i8], [1 x i8]* @.str.579, i64 0, i64 0
  %r523 = ptrtoint i8* %r522 to i64
  %r524 = load i64, i64* @actor_target
  call i64 @_append_poly(i64 %r524, i64 %r523)
  %r525 = load i64, i64* @paradigm
  %r526 = call i64 @_eq(i64 %r525, i64 1)
  %r527 = icmp ne i64 %r526, 0
  br i1 %r527, label %L1916, label %L1918
L1916:
  %r528 = call i64 @apply_layout()
  br label %L1918
L1918:
  %r529 = load i64, i64* @actor_x
  %r530 = call i64 @mensura(i64 %r529)
  %r531 = sub i64 %r530, 1
  store i64 %r531, i64* @focused_node
  br label %L1912
L1912:
  store i64 1, i64* %ptr_needs_render
  br label %L1901
L1900:
  %r532 = load i64, i64* %ptr_k_code
  %r533 = call i64 @_eq(i64 %r532, i64 1)
  %r534 = icmp ne i64 %r533, 0
  br i1 %r534, label %L1919, label %L1920
L1919:
  %r535 = load i64, i64* @paradigm
  %r536 = sub i64 1, %r535
  store i64 %r536, i64* @paradigm
  %r537 = load i64, i64* @paradigm
  %r538 = call i64 @_eq(i64 %r537, i64 1)
  %r539 = icmp ne i64 %r538, 0
  br i1 %r539, label %L1922, label %L1923
L1922:
  store i64 0, i64* @cam_x
  store i64 0, i64* @cam_y
  store i64 100, i64* @cam_z
  %r540 = call i64 @apply_layout()
  %r541 = getelementptr [36 x i8], [36 x i8]* @.str.580, i64 0, i64 0
  %r542 = ptrtoint i8* %r541 to i64
  store i64 %r542, i64* @omni_text
  br label %L1924
L1923:
  %r543 = getelementptr [40 x i8], [40 x i8]* @.str.581, i64 0, i64 0
  %r544 = ptrtoint i8* %r543 to i64
  store i64 %r544, i64* @omni_text
  br label %L1924
L1924:
  store i64 1, i64* %ptr_needs_render
  br label %L1921
L1920:
  %r545 = load i64, i64* %ptr_is_shifted
  store i64 %r545, i64* %ptr_use_shift
  store i64 0, i64* %ptr_is_letter
  %r546 = load i64, i64* %ptr_k_code
  %r548 = icmp sge i64 %r546, 16
  %r547 = zext i1 %r548 to i64
  store i64 0, i64* @.sc.582
  %r550 = icmp ne i64 %r547, 0
  br i1 %r550, label %L1925, label %L1926
L1925:
  %r551 = load i64, i64* %ptr_k_code
  %r553 = icmp sle i64 %r551, 25
  %r552 = zext i1 %r553 to i64
  %r554 = icmp ne i64 %r552, 0
  %r555 = zext i1 %r554 to i64
  store i64 %r555, i64* @.sc.582
  br label %L1926
L1926:
  %r549 = load i64, i64* @.sc.582
  %r556 = icmp ne i64 %r549, 0
  br i1 %r556, label %L1927, label %L1929
L1927:
  store i64 1, i64* %ptr_is_letter
  br label %L1929
L1929:
  %r557 = load i64, i64* %ptr_k_code
  %r559 = icmp sge i64 %r557, 30
  %r558 = zext i1 %r559 to i64
  store i64 0, i64* @.sc.583
  %r561 = icmp ne i64 %r558, 0
  br i1 %r561, label %L1930, label %L1931
L1930:
  %r562 = load i64, i64* %ptr_k_code
  %r564 = icmp sle i64 %r562, 38
  %r563 = zext i1 %r564 to i64
  %r565 = icmp ne i64 %r563, 0
  %r566 = zext i1 %r565 to i64
  store i64 %r566, i64* @.sc.583
  br label %L1931
L1931:
  %r560 = load i64, i64* @.sc.583
  %r567 = icmp ne i64 %r560, 0
  br i1 %r567, label %L1932, label %L1934
L1932:
  store i64 1, i64* %ptr_is_letter
  br label %L1934
L1934:
  %r568 = load i64, i64* %ptr_k_code
  %r570 = icmp sge i64 %r568, 44
  %r569 = zext i1 %r570 to i64
  store i64 0, i64* @.sc.584
  %r572 = icmp ne i64 %r569, 0
  br i1 %r572, label %L1935, label %L1936
L1935:
  %r573 = load i64, i64* %ptr_k_code
  %r575 = icmp sle i64 %r573, 50
  %r574 = zext i1 %r575 to i64
  %r576 = icmp ne i64 %r574, 0
  %r577 = zext i1 %r576 to i64
  store i64 %r577, i64* @.sc.584
  br label %L1936
L1936:
  %r571 = load i64, i64* @.sc.584
  %r578 = icmp ne i64 %r571, 0
  br i1 %r578, label %L1937, label %L1939
L1937:
  store i64 1, i64* %ptr_is_letter
  br label %L1939
L1939:
  %r579 = load i64, i64* %ptr_is_caps
  store i64 0, i64* @.sc.585
  %r581 = icmp ne i64 %r579, 0
  br i1 %r581, label %L1940, label %L1941
L1940:
  %r582 = load i64, i64* %ptr_is_letter
  %r583 = icmp ne i64 %r582, 0
  %r584 = zext i1 %r583 to i64
  store i64 %r584, i64* @.sc.585
  br label %L1941
L1941:
  %r580 = load i64, i64* @.sc.585
  %r585 = icmp ne i64 %r580, 0
  br i1 %r585, label %L1942, label %L1944
L1942:
  %r586 = load i64, i64* %ptr_use_shift
  %r587 = call i64 @_eq(i64 %r586, i64 1)
  %r588 = icmp ne i64 %r587, 0
  br i1 %r588, label %L1945, label %L1946
L1945:
  store i64 0, i64* %ptr_use_shift
  br label %L1947
L1946:
  store i64 1, i64* %ptr_use_shift
  br label %L1947
L1947:
  br label %L1944
L1944:
  %r589 = getelementptr [1 x i8], [1 x i8]* @.str.586, i64 0, i64 0
  %r590 = ptrtoint i8* %r589 to i64
  store i64 %r590, i64* %ptr_key_str
  %r591 = load i64, i64* %ptr_use_shift
  %r592 = icmp ne i64 %r591, 0
  br i1 %r592, label %L1948, label %L1949
L1948:
  %r593 = load i64, i64* @shift_map
  %r594 = load i64, i64* %ptr_k_code
  %r595 = call i64 @_get(i64 %r593, i64 %r594)
  store i64 %r595, i64* %ptr_key_str
  br label %L1950
L1949:
  %r596 = load i64, i64* @kbd_map
  %r597 = load i64, i64* %ptr_k_code
  %r598 = call i64 @_get(i64 %r596, i64 %r597)
  store i64 %r598, i64* %ptr_key_str
  br label %L1950
L1950:
  %r599 = load i64, i64* @focused_node
  %r600 = sub i64 0, 1
  %r602 = call i64 @_eq(i64 %r599, i64 %r600)
  %r601 = xor i64 %r602, 1
  %r603 = icmp ne i64 %r601, 0
  br i1 %r603, label %L1951, label %L1952
L1951:
  %r604 = load i64, i64* %ptr_key_str
  %r605 = call i64 @mensura(i64 %r604)
  %r607 = icmp sgt i64 %r605, 0
  %r606 = zext i1 %r607 to i64
  %r608 = icmp ne i64 %r606, 0
  br i1 %r608, label %L1954, label %L1956
L1954:
  %r609 = load i64, i64* @focused_node
  %r610 = load i64, i64* %ptr_key_str
  %r611 = call i64 @send_msg(i64 %r609, i64 %r610)
  br label %L1956
L1956:
  br label %L1953
L1952:
  %r612 = load i64, i64* %ptr_key_str
  %r613 = getelementptr [10 x i8], [10 x i8]* @.str.587, i64 0, i64 0
  %r614 = ptrtoint i8* %r613 to i64
  %r615 = call i64 @_eq(i64 %r612, i64 %r614)
  %r616 = icmp ne i64 %r615, 0
  br i1 %r616, label %L1957, label %L1958
L1957:
  %r617 = load i64, i64* @omni_text
  %r618 = call i64 @mensura(i64 %r617)
  store i64 %r618, i64* %ptr_len
  %r619 = load i64, i64* %ptr_len
  %r621 = icmp sgt i64 %r619, 1
  %r620 = zext i1 %r621 to i64
  %r622 = icmp ne i64 %r620, 0
  br i1 %r622, label %L1960, label %L1961
L1960:
  %r623 = load i64, i64* @omni_text
  %r624 = load i64, i64* %ptr_len
  %r625 = sub i64 %r624, 1
  %r626 = call i64 @pars(i64 %r623, i64 0, i64 %r625)
  store i64 %r626, i64* @omni_text
  br label %L1962
L1961:
  %r627 = load i64, i64* %ptr_len
  %r628 = call i64 @_eq(i64 %r627, i64 1)
  %r629 = icmp ne i64 %r628, 0
  br i1 %r629, label %L1963, label %L1965
L1963:
  %r630 = getelementptr [1 x i8], [1 x i8]* @.str.588, i64 0, i64 0
  %r631 = ptrtoint i8* %r630 to i64
  store i64 %r631, i64* @omni_text
  br label %L1965
L1965:
  br label %L1962
L1962:
  br label %L1959
L1958:
  %r632 = load i64, i64* %ptr_key_str
  %r633 = getelementptr [6 x i8], [6 x i8]* @.str.589, i64 0, i64 0
  %r634 = ptrtoint i8* %r633 to i64
  %r635 = call i64 @_eq(i64 %r632, i64 %r634)
  %r636 = icmp ne i64 %r635, 0
  br i1 %r636, label %L1966, label %L1967
L1966:
  %r637 = load i64, i64* @omni_text
  %r638 = getelementptr [6 x i8], [6 x i8]* @.str.590, i64 0, i64 0
  %r639 = ptrtoint i8* %r638 to i64
  %r640 = call i64 @_eq(i64 %r637, i64 %r639)
  %r641 = icmp ne i64 %r640, 0
  br i1 %r641, label %L1969, label %L1971
L1969:
  %r642 = sub i64 0, 1
  store i64 %r642, i64* %ptr_slot
  store i64 0, i64* %ptr_c
  br label %L1972
L1972:
  %r643 = load i64, i64* %ptr_c
  %r644 = load i64, i64* @actor_x
  %r645 = call i64 @mensura(i64 %r644)
  %r647 = icmp slt i64 %r643, %r645
  %r646 = zext i1 %r647 to i64
  %r648 = icmp ne i64 %r646, 0
  br i1 %r648, label %L1973, label %L1974
L1973:
  %r649 = load i64, i64* @actor_app
  %r650 = load i64, i64* %ptr_c
  %r651 = call i64 @_get(i64 %r649, i64 %r650)
  %r652 = sub i64 0, 1
  %r653 = call i64 @_eq(i64 %r651, i64 %r652)
  store i64 0, i64* @.sc.591
  %r655 = icmp ne i64 %r653, 0
  br i1 %r655, label %L1975, label %L1976
L1975:
  %r656 = load i64, i64* %ptr_slot
  %r657 = sub i64 0, 1
  %r658 = call i64 @_eq(i64 %r656, i64 %r657)
  %r659 = icmp ne i64 %r658, 0
  %r660 = zext i1 %r659 to i64
  store i64 %r660, i64* @.sc.591
  br label %L1976
L1976:
  %r654 = load i64, i64* @.sc.591
  %r661 = icmp ne i64 %r654, 0
  br i1 %r661, label %L1977, label %L1979
L1977:
  %r662 = load i64, i64* %ptr_c
  store i64 %r662, i64* %ptr_slot
  br label %L1979
L1979:
  %r663 = load i64, i64* %ptr_c
  %r664 = call i64 @_add(i64 %r663, i64 1)
  store i64 %r664, i64* %ptr_c
  br label %L1972
L1974:
  %r665 = load i64, i64* %ptr_slot
  %r666 = sub i64 0, 1
  %r668 = call i64 @_eq(i64 %r665, i64 %r666)
  %r667 = xor i64 %r668, 1
  %r669 = icmp ne i64 %r667, 0
  br i1 %r669, label %L1980, label %L1981
L1980:
  %r670 = load i64, i64* @cam_x
  %r671 = call i64 @_add(i64 %r670, i64 100)
  %r672 = load i64, i64* %ptr_slot
  %r673 = load i64, i64* @actor_x
  call i64 @_set(i64 %r673, i64 %r672, i64 %r671)
  %r674 = load i64, i64* @cam_y
  %r675 = call i64 @_add(i64 %r674, i64 100)
  %r676 = load i64, i64* %ptr_slot
  %r677 = load i64, i64* @actor_y
  call i64 @_set(i64 %r677, i64 %r676, i64 %r675)
  %r678 = load i64, i64* %ptr_slot
  %r679 = load i64, i64* @actor_w
  call i64 @_set(i64 %r679, i64 %r678, i64 400)
  %r680 = load i64, i64* %ptr_slot
  %r681 = load i64, i64* @actor_h
  call i64 @_set(i64 %r681, i64 %r680, i64 300)
  %r682 = getelementptr [31 x i8], [31 x i8]* @.str.592, i64 0, i64 0
  %r683 = ptrtoint i8* %r682 to i64
  %r684 = load i64, i64* %ptr_slot
  %r685 = load i64, i64* @actor_text
  call i64 @_set(i64 %r685, i64 %r684, i64 %r683)
  %r686 = getelementptr [1 x i8], [1 x i8]* @.str.593, i64 0, i64 0
  %r687 = ptrtoint i8* %r686 to i64
  %r688 = load i64, i64* %ptr_slot
  %r689 = load i64, i64* @actor_cmd
  call i64 @_set(i64 %r689, i64 %r688, i64 %r687)
  %r690 = getelementptr [1 x i8], [1 x i8]* @.str.594, i64 0, i64 0
  %r691 = ptrtoint i8* %r690 to i64
  %r692 = load i64, i64* %ptr_slot
  %r693 = load i64, i64* @actor_mailbox
  call i64 @_set(i64 %r693, i64 %r692, i64 %r691)
  %r694 = load i64, i64* %ptr_slot
  %r695 = load i64, i64* @actor_budget
  call i64 @_set(i64 %r695, i64 %r694, i64 0)
  %r696 = load i64, i64* %ptr_slot
  %r697 = load i64, i64* @actor_app
  call i64 @_set(i64 %r697, i64 %r696, i64 0)
  %r698 = getelementptr [1 x i8], [1 x i8]* @.str.595, i64 0, i64 0
  %r699 = ptrtoint i8* %r698 to i64
  %r700 = load i64, i64* %ptr_slot
  %r701 = load i64, i64* @actor_file_buf
  call i64 @_set(i64 %r701, i64 %r700, i64 %r699)
  %r702 = getelementptr [1 x i8], [1 x i8]* @.str.596, i64 0, i64 0
  %r703 = ptrtoint i8* %r702 to i64
  %r704 = load i64, i64* %ptr_slot
  %r705 = load i64, i64* @actor_target
  call i64 @_set(i64 %r705, i64 %r704, i64 %r703)
  %r706 = load i64, i64* @paradigm
  %r707 = call i64 @_eq(i64 %r706, i64 1)
  %r708 = icmp ne i64 %r707, 0
  br i1 %r708, label %L1983, label %L1985
L1983:
  %r709 = call i64 @apply_layout()
  br label %L1985
L1985:
  %r710 = load i64, i64* %ptr_slot
  store i64 %r710, i64* @focused_node
  br label %L1982
L1981:
  %r711 = load i64, i64* @cam_x
  %r712 = call i64 @_add(i64 %r711, i64 100)
  %r713 = load i64, i64* @actor_x
  call i64 @_append_poly(i64 %r713, i64 %r712)
  %r714 = load i64, i64* @cam_y
  %r715 = call i64 @_add(i64 %r714, i64 100)
  %r716 = load i64, i64* @actor_y
  call i64 @_append_poly(i64 %r716, i64 %r715)
  %r717 = load i64, i64* @actor_w
  call i64 @_append_poly(i64 %r717, i64 400)
  %r718 = load i64, i64* @actor_h
  call i64 @_append_poly(i64 %r718, i64 300)
  %r719 = getelementptr [31 x i8], [31 x i8]* @.str.597, i64 0, i64 0
  %r720 = ptrtoint i8* %r719 to i64
  %r721 = load i64, i64* @actor_text
  call i64 @_append_poly(i64 %r721, i64 %r720)
  %r722 = getelementptr [1 x i8], [1 x i8]* @.str.598, i64 0, i64 0
  %r723 = ptrtoint i8* %r722 to i64
  %r724 = load i64, i64* @actor_cmd
  call i64 @_append_poly(i64 %r724, i64 %r723)
  %r725 = getelementptr [1 x i8], [1 x i8]* @.str.599, i64 0, i64 0
  %r726 = ptrtoint i8* %r725 to i64
  %r727 = load i64, i64* @actor_mailbox
  call i64 @_append_poly(i64 %r727, i64 %r726)
  %r728 = load i64, i64* @actor_budget
  call i64 @_append_poly(i64 %r728, i64 0)
  %r729 = load i64, i64* @actor_app
  call i64 @_append_poly(i64 %r729, i64 0)
  %r730 = getelementptr [1 x i8], [1 x i8]* @.str.600, i64 0, i64 0
  %r731 = ptrtoint i8* %r730 to i64
  %r732 = load i64, i64* @actor_file_buf
  call i64 @_append_poly(i64 %r732, i64 %r731)
  %r733 = getelementptr [1 x i8], [1 x i8]* @.str.601, i64 0, i64 0
  %r734 = ptrtoint i8* %r733 to i64
  %r735 = load i64, i64* @actor_target
  call i64 @_append_poly(i64 %r735, i64 %r734)
  %r736 = load i64, i64* @paradigm
  %r737 = call i64 @_eq(i64 %r736, i64 1)
  %r738 = icmp ne i64 %r737, 0
  br i1 %r738, label %L1986, label %L1988
L1986:
  %r739 = call i64 @apply_layout()
  br label %L1988
L1988:
  %r740 = load i64, i64* @actor_x
  %r741 = call i64 @mensura(i64 %r740)
  %r742 = sub i64 %r741, 1
  store i64 %r742, i64* @focused_node
  br label %L1982
L1982:
  br label %L1971
L1971:
  %r743 = getelementptr [1 x i8], [1 x i8]* @.str.602, i64 0, i64 0
  %r744 = ptrtoint i8* %r743 to i64
  store i64 %r744, i64* @omni_text
  br label %L1968
L1967:
  %r745 = load i64, i64* %ptr_key_str
  %r746 = call i64 @mensura(i64 %r745)
  %r748 = icmp sgt i64 %r746, 0
  %r747 = zext i1 %r748 to i64
  %r749 = icmp ne i64 %r747, 0
  br i1 %r749, label %L1989, label %L1991
L1989:
  %r750 = load i64, i64* @omni_text
  %r751 = load i64, i64* %ptr_key_str
  %r752 = call i64 @_add(i64 %r750, i64 %r751)
  store i64 %r752, i64* @omni_text
  br label %L1991
L1991:
  br label %L1968
L1968:
  br label %L1959
L1959:
  br label %L1953
L1953:
  store i64 1, i64* %ptr_needs_render
  br label %L1921
L1921:
  br label %L1901
L1901:
  br label %L1892
L1892:
  br label %L1884
L1884:
  br label %L1881
L1881:
  br label %L1871
L1871:
  br label %L1753
L1753:
  br label %L1750
L1749:
  %r753 = call i64 @render_particles()
  store i64 %r753, i64* %ptr_parts_active
  %r754 = load i64, i64* %ptr_needs_render
  store i64 1, i64* @.sc.603
  %r756 = icmp eq i64 %r754, 0
  br i1 %r756, label %L1992, label %L1993
L1992:
  %r757 = load i64, i64* %ptr_parts_active
  %r758 = icmp ne i64 %r757, 0
  %r759 = zext i1 %r758 to i64
  store i64 %r759, i64* @.sc.603
  br label %L1993
L1993:
  %r755 = load i64, i64* @.sc.603
  %r760 = icmp ne i64 %r755, 0
  br i1 %r760, label %L1994, label %L1996
L1994:
  %r761 = call i64 @scheduler_tick()
  %r762 = call i64 @render_frame()
  store i64 0, i64* %ptr_needs_render
  br label %L1996
L1996:
  br label %L1750
L1750:
  br label %L1745
L1747:
  ret i64 0
  ret i64 0
}
define void @_achlys_init() {
  store i64 16777216, i64* @kernel_heap
  store i64 0, i64* @FB_ADDR
  store i64 0, i64* @BACK_BUFFER
  store i64 0, i64* @FB_PITCH
  store i64 0, i64* @FB_WIDTH
  store i64 0, i64* @FB_HEIGHT
  %r1 = call i64 @_list_new()
  %r2 = getelementptr [1 x i8], [1 x i8]* @.str.604, i64 0, i64 0
  %r3 = ptrtoint i8* %r2 to i64
  call i64 @_list_push(i64 %r1, i64 %r3)
  %r4 = getelementptr [4 x i8], [4 x i8]* @.str.605, i64 0, i64 0
  %r5 = ptrtoint i8* %r4 to i64
  call i64 @_list_push(i64 %r1, i64 %r5)
  %r6 = getelementptr [2 x i8], [2 x i8]* @.str.606, i64 0, i64 0
  %r7 = ptrtoint i8* %r6 to i64
  call i64 @_list_push(i64 %r1, i64 %r7)
  %r8 = getelementptr [2 x i8], [2 x i8]* @.str.607, i64 0, i64 0
  %r9 = ptrtoint i8* %r8 to i64
  call i64 @_list_push(i64 %r1, i64 %r9)
  %r10 = getelementptr [2 x i8], [2 x i8]* @.str.608, i64 0, i64 0
  %r11 = ptrtoint i8* %r10 to i64
  call i64 @_list_push(i64 %r1, i64 %r11)
  %r12 = getelementptr [2 x i8], [2 x i8]* @.str.609, i64 0, i64 0
  %r13 = ptrtoint i8* %r12 to i64
  call i64 @_list_push(i64 %r1, i64 %r13)
  %r14 = getelementptr [2 x i8], [2 x i8]* @.str.610, i64 0, i64 0
  %r15 = ptrtoint i8* %r14 to i64
  call i64 @_list_push(i64 %r1, i64 %r15)
  %r16 = getelementptr [2 x i8], [2 x i8]* @.str.611, i64 0, i64 0
  %r17 = ptrtoint i8* %r16 to i64
  call i64 @_list_push(i64 %r1, i64 %r17)
  %r18 = getelementptr [2 x i8], [2 x i8]* @.str.612, i64 0, i64 0
  %r19 = ptrtoint i8* %r18 to i64
  call i64 @_list_push(i64 %r1, i64 %r19)
  %r20 = getelementptr [2 x i8], [2 x i8]* @.str.613, i64 0, i64 0
  %r21 = ptrtoint i8* %r20 to i64
  call i64 @_list_push(i64 %r1, i64 %r21)
  %r22 = getelementptr [2 x i8], [2 x i8]* @.str.614, i64 0, i64 0
  %r23 = ptrtoint i8* %r22 to i64
  call i64 @_list_push(i64 %r1, i64 %r23)
  %r24 = getelementptr [2 x i8], [2 x i8]* @.str.615, i64 0, i64 0
  %r25 = ptrtoint i8* %r24 to i64
  call i64 @_list_push(i64 %r1, i64 %r25)
  %r26 = getelementptr [2 x i8], [2 x i8]* @.str.616, i64 0, i64 0
  %r27 = ptrtoint i8* %r26 to i64
  call i64 @_list_push(i64 %r1, i64 %r27)
  %r28 = getelementptr [2 x i8], [2 x i8]* @.str.617, i64 0, i64 0
  %r29 = ptrtoint i8* %r28 to i64
  call i64 @_list_push(i64 %r1, i64 %r29)
  %r30 = getelementptr [10 x i8], [10 x i8]* @.str.618, i64 0, i64 0
  %r31 = ptrtoint i8* %r30 to i64
  call i64 @_list_push(i64 %r1, i64 %r31)
  %r32 = getelementptr [4 x i8], [4 x i8]* @.str.619, i64 0, i64 0
  %r33 = ptrtoint i8* %r32 to i64
  call i64 @_list_push(i64 %r1, i64 %r33)
  %r34 = getelementptr [2 x i8], [2 x i8]* @.str.620, i64 0, i64 0
  %r35 = ptrtoint i8* %r34 to i64
  call i64 @_list_push(i64 %r1, i64 %r35)
  %r36 = getelementptr [2 x i8], [2 x i8]* @.str.621, i64 0, i64 0
  %r37 = ptrtoint i8* %r36 to i64
  call i64 @_list_push(i64 %r1, i64 %r37)
  %r38 = getelementptr [2 x i8], [2 x i8]* @.str.622, i64 0, i64 0
  %r39 = ptrtoint i8* %r38 to i64
  call i64 @_list_push(i64 %r1, i64 %r39)
  %r40 = getelementptr [2 x i8], [2 x i8]* @.str.623, i64 0, i64 0
  %r41 = ptrtoint i8* %r40 to i64
  call i64 @_list_push(i64 %r1, i64 %r41)
  %r42 = getelementptr [2 x i8], [2 x i8]* @.str.624, i64 0, i64 0
  %r43 = ptrtoint i8* %r42 to i64
  call i64 @_list_push(i64 %r1, i64 %r43)
  %r44 = getelementptr [2 x i8], [2 x i8]* @.str.625, i64 0, i64 0
  %r45 = ptrtoint i8* %r44 to i64
  call i64 @_list_push(i64 %r1, i64 %r45)
  %r46 = getelementptr [2 x i8], [2 x i8]* @.str.626, i64 0, i64 0
  %r47 = ptrtoint i8* %r46 to i64
  call i64 @_list_push(i64 %r1, i64 %r47)
  %r48 = getelementptr [2 x i8], [2 x i8]* @.str.627, i64 0, i64 0
  %r49 = ptrtoint i8* %r48 to i64
  call i64 @_list_push(i64 %r1, i64 %r49)
  %r50 = getelementptr [2 x i8], [2 x i8]* @.str.628, i64 0, i64 0
  %r51 = ptrtoint i8* %r50 to i64
  call i64 @_list_push(i64 %r1, i64 %r51)
  %r52 = getelementptr [2 x i8], [2 x i8]* @.str.629, i64 0, i64 0
  %r53 = ptrtoint i8* %r52 to i64
  call i64 @_list_push(i64 %r1, i64 %r53)
  %r54 = getelementptr [2 x i8], [2 x i8]* @.str.630, i64 0, i64 0
  %r55 = ptrtoint i8* %r54 to i64
  call i64 @_list_push(i64 %r1, i64 %r55)
  %r56 = getelementptr [2 x i8], [2 x i8]* @.str.631, i64 0, i64 0
  %r57 = ptrtoint i8* %r56 to i64
  call i64 @_list_push(i64 %r1, i64 %r57)
  %r58 = getelementptr [6 x i8], [6 x i8]* @.str.632, i64 0, i64 0
  %r59 = ptrtoint i8* %r58 to i64
  call i64 @_list_push(i64 %r1, i64 %r59)
  %r60 = getelementptr [5 x i8], [5 x i8]* @.str.633, i64 0, i64 0
  %r61 = ptrtoint i8* %r60 to i64
  call i64 @_list_push(i64 %r1, i64 %r61)
  %r62 = getelementptr [2 x i8], [2 x i8]* @.str.634, i64 0, i64 0
  %r63 = ptrtoint i8* %r62 to i64
  call i64 @_list_push(i64 %r1, i64 %r63)
  %r64 = getelementptr [2 x i8], [2 x i8]* @.str.635, i64 0, i64 0
  %r65 = ptrtoint i8* %r64 to i64
  call i64 @_list_push(i64 %r1, i64 %r65)
  %r66 = getelementptr [2 x i8], [2 x i8]* @.str.636, i64 0, i64 0
  %r67 = ptrtoint i8* %r66 to i64
  call i64 @_list_push(i64 %r1, i64 %r67)
  %r68 = getelementptr [2 x i8], [2 x i8]* @.str.637, i64 0, i64 0
  %r69 = ptrtoint i8* %r68 to i64
  call i64 @_list_push(i64 %r1, i64 %r69)
  %r70 = getelementptr [2 x i8], [2 x i8]* @.str.638, i64 0, i64 0
  %r71 = ptrtoint i8* %r70 to i64
  call i64 @_list_push(i64 %r1, i64 %r71)
  %r72 = getelementptr [2 x i8], [2 x i8]* @.str.639, i64 0, i64 0
  %r73 = ptrtoint i8* %r72 to i64
  call i64 @_list_push(i64 %r1, i64 %r73)
  %r74 = getelementptr [2 x i8], [2 x i8]* @.str.640, i64 0, i64 0
  %r75 = ptrtoint i8* %r74 to i64
  call i64 @_list_push(i64 %r1, i64 %r75)
  %r76 = getelementptr [2 x i8], [2 x i8]* @.str.641, i64 0, i64 0
  %r77 = ptrtoint i8* %r76 to i64
  call i64 @_list_push(i64 %r1, i64 %r77)
  %r78 = getelementptr [2 x i8], [2 x i8]* @.str.642, i64 0, i64 0
  %r79 = ptrtoint i8* %r78 to i64
  call i64 @_list_push(i64 %r1, i64 %r79)
  %r80 = getelementptr [2 x i8], [2 x i8]* @.str.643, i64 0, i64 0
  %r81 = ptrtoint i8* %r80 to i64
  call i64 @_list_push(i64 %r1, i64 %r81)
  %r82 = getelementptr [2 x i8], [2 x i8]* @.str.644, i64 0, i64 0
  %r83 = ptrtoint i8* %r82 to i64
  call i64 @_list_push(i64 %r1, i64 %r83)
  %r84 = getelementptr [2 x i8], [2 x i8]* @.str.645, i64 0, i64 0
  %r85 = ptrtoint i8* %r84 to i64
  call i64 @_list_push(i64 %r1, i64 %r85)
  %r86 = getelementptr [7 x i8], [7 x i8]* @.str.646, i64 0, i64 0
  %r87 = ptrtoint i8* %r86 to i64
  call i64 @_list_push(i64 %r1, i64 %r87)
  %r88 = getelementptr [2 x i8], [2 x i8]* @.str.647, i64 0, i64 0
  %r89 = ptrtoint i8* %r88 to i64
  call i64 @_list_push(i64 %r1, i64 %r89)
  %r90 = getelementptr [2 x i8], [2 x i8]* @.str.648, i64 0, i64 0
  %r91 = ptrtoint i8* %r90 to i64
  call i64 @_list_push(i64 %r1, i64 %r91)
  %r92 = getelementptr [2 x i8], [2 x i8]* @.str.649, i64 0, i64 0
  %r93 = ptrtoint i8* %r92 to i64
  call i64 @_list_push(i64 %r1, i64 %r93)
  %r94 = getelementptr [2 x i8], [2 x i8]* @.str.650, i64 0, i64 0
  %r95 = ptrtoint i8* %r94 to i64
  call i64 @_list_push(i64 %r1, i64 %r95)
  %r96 = getelementptr [2 x i8], [2 x i8]* @.str.651, i64 0, i64 0
  %r97 = ptrtoint i8* %r96 to i64
  call i64 @_list_push(i64 %r1, i64 %r97)
  %r98 = getelementptr [2 x i8], [2 x i8]* @.str.652, i64 0, i64 0
  %r99 = ptrtoint i8* %r98 to i64
  call i64 @_list_push(i64 %r1, i64 %r99)
  %r100 = getelementptr [2 x i8], [2 x i8]* @.str.653, i64 0, i64 0
  %r101 = ptrtoint i8* %r100 to i64
  call i64 @_list_push(i64 %r1, i64 %r101)
  %r102 = getelementptr [2 x i8], [2 x i8]* @.str.654, i64 0, i64 0
  %r103 = ptrtoint i8* %r102 to i64
  call i64 @_list_push(i64 %r1, i64 %r103)
  %r104 = getelementptr [2 x i8], [2 x i8]* @.str.655, i64 0, i64 0
  %r105 = ptrtoint i8* %r104 to i64
  call i64 @_list_push(i64 %r1, i64 %r105)
  %r106 = getelementptr [2 x i8], [2 x i8]* @.str.656, i64 0, i64 0
  %r107 = ptrtoint i8* %r106 to i64
  call i64 @_list_push(i64 %r1, i64 %r107)
  %r108 = getelementptr [2 x i8], [2 x i8]* @.str.657, i64 0, i64 0
  %r109 = ptrtoint i8* %r108 to i64
  call i64 @_list_push(i64 %r1, i64 %r109)
  %r110 = getelementptr [7 x i8], [7 x i8]* @.str.658, i64 0, i64 0
  %r111 = ptrtoint i8* %r110 to i64
  call i64 @_list_push(i64 %r1, i64 %r111)
  %r112 = getelementptr [2 x i8], [2 x i8]* @.str.659, i64 0, i64 0
  %r113 = ptrtoint i8* %r112 to i64
  call i64 @_list_push(i64 %r1, i64 %r113)
  %r114 = getelementptr [4 x i8], [4 x i8]* @.str.660, i64 0, i64 0
  %r115 = ptrtoint i8* %r114 to i64
  call i64 @_list_push(i64 %r1, i64 %r115)
  %r116 = getelementptr [2 x i8], [2 x i8]* @.str.661, i64 0, i64 0
  %r117 = ptrtoint i8* %r116 to i64
  call i64 @_list_push(i64 %r1, i64 %r117)
  store i64 %r1, i64* @kbd_map
  %r118 = call i64 @_list_new()
  %r119 = getelementptr [1 x i8], [1 x i8]* @.str.662, i64 0, i64 0
  %r120 = ptrtoint i8* %r119 to i64
  call i64 @_list_push(i64 %r118, i64 %r120)
  %r121 = getelementptr [4 x i8], [4 x i8]* @.str.663, i64 0, i64 0
  %r122 = ptrtoint i8* %r121 to i64
  call i64 @_list_push(i64 %r118, i64 %r122)
  %r123 = getelementptr [2 x i8], [2 x i8]* @.str.664, i64 0, i64 0
  %r124 = ptrtoint i8* %r123 to i64
  call i64 @_list_push(i64 %r118, i64 %r124)
  %r125 = getelementptr [2 x i8], [2 x i8]* @.str.665, i64 0, i64 0
  %r126 = ptrtoint i8* %r125 to i64
  call i64 @_list_push(i64 %r118, i64 %r126)
  %r127 = getelementptr [2 x i8], [2 x i8]* @.str.666, i64 0, i64 0
  %r128 = ptrtoint i8* %r127 to i64
  call i64 @_list_push(i64 %r118, i64 %r128)
  %r129 = getelementptr [2 x i8], [2 x i8]* @.str.667, i64 0, i64 0
  %r130 = ptrtoint i8* %r129 to i64
  call i64 @_list_push(i64 %r118, i64 %r130)
  %r131 = getelementptr [2 x i8], [2 x i8]* @.str.668, i64 0, i64 0
  %r132 = ptrtoint i8* %r131 to i64
  call i64 @_list_push(i64 %r118, i64 %r132)
  %r133 = getelementptr [2 x i8], [2 x i8]* @.str.669, i64 0, i64 0
  %r134 = ptrtoint i8* %r133 to i64
  call i64 @_list_push(i64 %r118, i64 %r134)
  %r135 = getelementptr [2 x i8], [2 x i8]* @.str.670, i64 0, i64 0
  %r136 = ptrtoint i8* %r135 to i64
  call i64 @_list_push(i64 %r118, i64 %r136)
  %r137 = getelementptr [2 x i8], [2 x i8]* @.str.671, i64 0, i64 0
  %r138 = ptrtoint i8* %r137 to i64
  call i64 @_list_push(i64 %r118, i64 %r138)
  %r139 = getelementptr [2 x i8], [2 x i8]* @.str.672, i64 0, i64 0
  %r140 = ptrtoint i8* %r139 to i64
  call i64 @_list_push(i64 %r118, i64 %r140)
  %r141 = getelementptr [2 x i8], [2 x i8]* @.str.673, i64 0, i64 0
  %r142 = ptrtoint i8* %r141 to i64
  call i64 @_list_push(i64 %r118, i64 %r142)
  %r143 = getelementptr [2 x i8], [2 x i8]* @.str.674, i64 0, i64 0
  %r144 = ptrtoint i8* %r143 to i64
  call i64 @_list_push(i64 %r118, i64 %r144)
  %r145 = getelementptr [2 x i8], [2 x i8]* @.str.675, i64 0, i64 0
  %r146 = ptrtoint i8* %r145 to i64
  call i64 @_list_push(i64 %r118, i64 %r146)
  %r147 = getelementptr [10 x i8], [10 x i8]* @.str.676, i64 0, i64 0
  %r148 = ptrtoint i8* %r147 to i64
  call i64 @_list_push(i64 %r118, i64 %r148)
  %r149 = getelementptr [4 x i8], [4 x i8]* @.str.677, i64 0, i64 0
  %r150 = ptrtoint i8* %r149 to i64
  call i64 @_list_push(i64 %r118, i64 %r150)
  %r151 = getelementptr [2 x i8], [2 x i8]* @.str.678, i64 0, i64 0
  %r152 = ptrtoint i8* %r151 to i64
  call i64 @_list_push(i64 %r118, i64 %r152)
  %r153 = getelementptr [2 x i8], [2 x i8]* @.str.679, i64 0, i64 0
  %r154 = ptrtoint i8* %r153 to i64
  call i64 @_list_push(i64 %r118, i64 %r154)
  %r155 = getelementptr [2 x i8], [2 x i8]* @.str.680, i64 0, i64 0
  %r156 = ptrtoint i8* %r155 to i64
  call i64 @_list_push(i64 %r118, i64 %r156)
  %r157 = getelementptr [2 x i8], [2 x i8]* @.str.681, i64 0, i64 0
  %r158 = ptrtoint i8* %r157 to i64
  call i64 @_list_push(i64 %r118, i64 %r158)
  %r159 = getelementptr [2 x i8], [2 x i8]* @.str.682, i64 0, i64 0
  %r160 = ptrtoint i8* %r159 to i64
  call i64 @_list_push(i64 %r118, i64 %r160)
  %r161 = getelementptr [2 x i8], [2 x i8]* @.str.683, i64 0, i64 0
  %r162 = ptrtoint i8* %r161 to i64
  call i64 @_list_push(i64 %r118, i64 %r162)
  %r163 = getelementptr [2 x i8], [2 x i8]* @.str.684, i64 0, i64 0
  %r164 = ptrtoint i8* %r163 to i64
  call i64 @_list_push(i64 %r118, i64 %r164)
  %r165 = getelementptr [2 x i8], [2 x i8]* @.str.685, i64 0, i64 0
  %r166 = ptrtoint i8* %r165 to i64
  call i64 @_list_push(i64 %r118, i64 %r166)
  %r167 = getelementptr [2 x i8], [2 x i8]* @.str.686, i64 0, i64 0
  %r168 = ptrtoint i8* %r167 to i64
  call i64 @_list_push(i64 %r118, i64 %r168)
  %r169 = getelementptr [2 x i8], [2 x i8]* @.str.687, i64 0, i64 0
  %r170 = ptrtoint i8* %r169 to i64
  call i64 @_list_push(i64 %r118, i64 %r170)
  %r171 = getelementptr [2 x i8], [2 x i8]* @.str.688, i64 0, i64 0
  %r172 = ptrtoint i8* %r171 to i64
  call i64 @_list_push(i64 %r118, i64 %r172)
  %r173 = getelementptr [2 x i8], [2 x i8]* @.str.689, i64 0, i64 0
  %r174 = ptrtoint i8* %r173 to i64
  call i64 @_list_push(i64 %r118, i64 %r174)
  %r175 = getelementptr [6 x i8], [6 x i8]* @.str.690, i64 0, i64 0
  %r176 = ptrtoint i8* %r175 to i64
  call i64 @_list_push(i64 %r118, i64 %r176)
  %r177 = getelementptr [5 x i8], [5 x i8]* @.str.691, i64 0, i64 0
  %r178 = ptrtoint i8* %r177 to i64
  call i64 @_list_push(i64 %r118, i64 %r178)
  %r179 = getelementptr [2 x i8], [2 x i8]* @.str.692, i64 0, i64 0
  %r180 = ptrtoint i8* %r179 to i64
  call i64 @_list_push(i64 %r118, i64 %r180)
  %r181 = getelementptr [2 x i8], [2 x i8]* @.str.693, i64 0, i64 0
  %r182 = ptrtoint i8* %r181 to i64
  call i64 @_list_push(i64 %r118, i64 %r182)
  %r183 = getelementptr [2 x i8], [2 x i8]* @.str.694, i64 0, i64 0
  %r184 = ptrtoint i8* %r183 to i64
  call i64 @_list_push(i64 %r118, i64 %r184)
  %r185 = getelementptr [2 x i8], [2 x i8]* @.str.695, i64 0, i64 0
  %r186 = ptrtoint i8* %r185 to i64
  call i64 @_list_push(i64 %r118, i64 %r186)
  %r187 = getelementptr [2 x i8], [2 x i8]* @.str.696, i64 0, i64 0
  %r188 = ptrtoint i8* %r187 to i64
  call i64 @_list_push(i64 %r118, i64 %r188)
  %r189 = getelementptr [2 x i8], [2 x i8]* @.str.697, i64 0, i64 0
  %r190 = ptrtoint i8* %r189 to i64
  call i64 @_list_push(i64 %r118, i64 %r190)
  %r191 = getelementptr [2 x i8], [2 x i8]* @.str.698, i64 0, i64 0
  %r192 = ptrtoint i8* %r191 to i64
  call i64 @_list_push(i64 %r118, i64 %r192)
  %r193 = getelementptr [2 x i8], [2 x i8]* @.str.699, i64 0, i64 0
  %r194 = ptrtoint i8* %r193 to i64
  call i64 @_list_push(i64 %r118, i64 %r194)
  %r195 = getelementptr [2 x i8], [2 x i8]* @.str.700, i64 0, i64 0
  %r196 = ptrtoint i8* %r195 to i64
  call i64 @_list_push(i64 %r118, i64 %r196)
  %r197 = getelementptr [2 x i8], [2 x i8]* @.str.701, i64 0, i64 0
  %r198 = ptrtoint i8* %r197 to i64
  call i64 @_list_push(i64 %r118, i64 %r198)
  %r199 = getelementptr [2 x i8], [2 x i8]* @.str.702, i64 0, i64 0
  %r200 = ptrtoint i8* %r199 to i64
  call i64 @_list_push(i64 %r118, i64 %r200)
  %r201 = getelementptr [2 x i8], [2 x i8]* @.str.703, i64 0, i64 0
  %r202 = ptrtoint i8* %r201 to i64
  call i64 @_list_push(i64 %r118, i64 %r202)
  %r203 = getelementptr [7 x i8], [7 x i8]* @.str.704, i64 0, i64 0
  %r204 = ptrtoint i8* %r203 to i64
  call i64 @_list_push(i64 %r118, i64 %r204)
  %r205 = getelementptr [2 x i8], [2 x i8]* @.str.705, i64 0, i64 0
  %r206 = ptrtoint i8* %r205 to i64
  call i64 @_list_push(i64 %r118, i64 %r206)
  %r207 = getelementptr [2 x i8], [2 x i8]* @.str.706, i64 0, i64 0
  %r208 = ptrtoint i8* %r207 to i64
  call i64 @_list_push(i64 %r118, i64 %r208)
  %r209 = getelementptr [2 x i8], [2 x i8]* @.str.707, i64 0, i64 0
  %r210 = ptrtoint i8* %r209 to i64
  call i64 @_list_push(i64 %r118, i64 %r210)
  %r211 = getelementptr [2 x i8], [2 x i8]* @.str.708, i64 0, i64 0
  %r212 = ptrtoint i8* %r211 to i64
  call i64 @_list_push(i64 %r118, i64 %r212)
  %r213 = getelementptr [2 x i8], [2 x i8]* @.str.709, i64 0, i64 0
  %r214 = ptrtoint i8* %r213 to i64
  call i64 @_list_push(i64 %r118, i64 %r214)
  %r215 = getelementptr [2 x i8], [2 x i8]* @.str.710, i64 0, i64 0
  %r216 = ptrtoint i8* %r215 to i64
  call i64 @_list_push(i64 %r118, i64 %r216)
  %r217 = getelementptr [2 x i8], [2 x i8]* @.str.711, i64 0, i64 0
  %r218 = ptrtoint i8* %r217 to i64
  call i64 @_list_push(i64 %r118, i64 %r218)
  %r219 = getelementptr [2 x i8], [2 x i8]* @.str.712, i64 0, i64 0
  %r220 = ptrtoint i8* %r219 to i64
  call i64 @_list_push(i64 %r118, i64 %r220)
  %r221 = getelementptr [2 x i8], [2 x i8]* @.str.713, i64 0, i64 0
  %r222 = ptrtoint i8* %r221 to i64
  call i64 @_list_push(i64 %r118, i64 %r222)
  %r223 = getelementptr [2 x i8], [2 x i8]* @.str.714, i64 0, i64 0
  %r224 = ptrtoint i8* %r223 to i64
  call i64 @_list_push(i64 %r118, i64 %r224)
  %r225 = getelementptr [2 x i8], [2 x i8]* @.str.715, i64 0, i64 0
  %r226 = ptrtoint i8* %r225 to i64
  call i64 @_list_push(i64 %r118, i64 %r226)
  %r227 = getelementptr [7 x i8], [7 x i8]* @.str.716, i64 0, i64 0
  %r228 = ptrtoint i8* %r227 to i64
  call i64 @_list_push(i64 %r118, i64 %r228)
  %r229 = getelementptr [2 x i8], [2 x i8]* @.str.717, i64 0, i64 0
  %r230 = ptrtoint i8* %r229 to i64
  call i64 @_list_push(i64 %r118, i64 %r230)
  %r231 = getelementptr [4 x i8], [4 x i8]* @.str.718, i64 0, i64 0
  %r232 = ptrtoint i8* %r231 to i64
  call i64 @_list_push(i64 %r118, i64 %r232)
  %r233 = getelementptr [2 x i8], [2 x i8]* @.str.719, i64 0, i64 0
  %r234 = ptrtoint i8* %r233 to i64
  call i64 @_list_push(i64 %r118, i64 %r234)
  store i64 %r118, i64* @shift_map
  %r235 = call i64 @_list_new()
  store i64 %r235, i64* @FONT
  store i64 0, i64* @cam_x
  store i64 0, i64* @cam_y
  store i64 100, i64* @cam_z
  store i64 512, i64* @mouse_x
  store i64 384, i64* @mouse_y
  store i64 0, i64* @mouse_l_down
  store i64 0, i64* @mouse_r_down
  store i64 0, i64* @E1000_BAR
  store i64 0, i64* @E1000_TX_DESC
  store i64 0, i64* @E1000_TX_TAIL
  store i64 0, i64* @E1000_RX_DESC
  store i64 0, i64* @E1000_RX_CUR
  store i64 0, i64* @E1000_RX_LEN
  store i64 0, i64* @TOK_EOF
  store i64 1, i64* @TOK_INT
  store i64 2, i64* @TOK_FLOAT
  store i64 3, i64* @TOK_STRING
  store i64 4, i64* @TOK_IDENT
  store i64 5, i64* @TOK_LET
  store i64 6, i64* @TOK_PRINT
  store i64 7, i64* @TOK_IF
  store i64 8, i64* @TOK_ELSE
  store i64 9, i64* @TOK_WHILE
  store i64 10, i64* @TOK_OPUS
  store i64 11, i64* @TOK_REDDO
  store i64 12, i64* @TOK_BREAK
  store i64 13, i64* @TOK_CONTINUE
  store i64 20, i64* @TOK_IMPORT
  store i64 21, i64* @TOK_LPAREN
  store i64 22, i64* @TOK_RPAREN
  store i64 23, i64* @TOK_LBRACE
  store i64 24, i64* @TOK_RBRACE
  store i64 25, i64* @TOK_LBRACKET
  store i64 26, i64* @TOK_RBRACKET
  store i64 27, i64* @TOK_COLON
  store i64 28, i64* @TOK_ARROW
  store i64 29, i64* @TOK_CARET
  store i64 30, i64* @TOK_DOT
  store i64 31, i64* @TOK_APPEND
  store i64 32, i64* @TOK_EXTRACT
  store i64 33, i64* @TOK_AND
  store i64 34, i64* @TOK_OR
  store i64 35, i64* @TOK_CONST
  store i64 36, i64* @TOK_SHARED
  store i64 37, i64* @TOK_OP
  store i64 38, i64* @TOK_COMMA
  store i64 100, i64* @EXPR_INT
  store i64 101, i64* @EXPR_FLOAT
  store i64 102, i64* @EXPR_STRING
  store i64 103, i64* @EXPR_VAR
  store i64 104, i64* @EXPR_LIST
  store i64 105, i64* @EXPR_MAP
  store i64 106, i64* @EXPR_BINARY
  store i64 107, i64* @EXPR_INDEX
  store i64 108, i64* @EXPR_GET
  store i64 109, i64* @EXPR_CALL
  store i64 110, i64* @EXPR_INPUT
  store i64 111, i64* @EXPR_READ
  store i64 112, i64* @EXPR_MEASURE
  store i64 200, i64* @STMT_LET
  store i64 201, i64* @STMT_ASSIGN
  store i64 202, i64* @STMT_SET
  store i64 203, i64* @STMT_SET_INDEX
  store i64 204, i64* @STMT_APPEND
  store i64 205, i64* @STMT_EXTRACT
  store i64 206, i64* @STMT_PRINT
  store i64 207, i64* @STMT_IF
  store i64 208, i64* @STMT_WHILE
  store i64 209, i64* @STMT_FUNC
  store i64 210, i64* @STMT_RETURN
  store i64 211, i64* @STMT_IMPORT
  store i64 212, i64* @STMT_BREAK
  store i64 213, i64* @STMT_CONTINUE
  store i64 214, i64* @STMT_EXPR
  store i64 215, i64* @STMT_CONST
  store i64 216, i64* @STMT_SHARED
  store i64 0, i64* @VAL_INT
  store i64 1, i64* @VAL_FLOAT
  store i64 2, i64* @VAL_STRING
  store i64 3, i64* @VAL_LIST
  store i64 4, i64* @VAL_MAP
  store i64 5, i64* @VAL_FUNC
  store i64 6, i64* @VAL_VOID
  %r236 = call i64 @_list_new()
  store i64 %r236, i64* @global_tokens
  store i64 0, i64* @p_pos
  store i64 0, i64* @has_error
  store i64 0, i64* @use_huge_lists
  %r237 = call i64 @_list_new()
  store i64 %r237, i64* @str_table
  %r238 = call i64 @_map_new()
  store i64 %r238, i64* @stack_map
  store i64 0, i64* @stack_offset
  store i64 0, i64* @lbl_counter
  %r239 = getelementptr [1 x i8], [1 x i8]* @.str.720, i64 0, i64 0
  %r240 = ptrtoint i8* %r239 to i64
  store i64 %r240, i64* @asm_main
  %r241 = getelementptr [1 x i8], [1 x i8]* @.str.721, i64 0, i64 0
  %r242 = ptrtoint i8* %r241 to i64
  store i64 %r242, i64* @asm_funcs
  store i64 0, i64* @in_func
  %r243 = call i64 @_list_new()
  store i64 %r243, i64* @local_vars
  store i64 0, i64* @stack_depth
  %r244 = call i64 @_map_new()
  store i64 %r244, i64* @runtime_env
  %r245 = sub i64 0, 1
  store i64 %r245, i64* @eval_terminal
  %r246 = call i64 @_list_new()
  store i64 %r246, i64* @actor_x
  %r247 = call i64 @_list_new()
  store i64 %r247, i64* @actor_y
  %r248 = call i64 @_list_new()
  store i64 %r248, i64* @actor_w
  %r249 = call i64 @_list_new()
  store i64 %r249, i64* @actor_h
  %r250 = call i64 @_list_new()
  store i64 %r250, i64* @actor_text
  %r251 = call i64 @_list_new()
  store i64 %r251, i64* @actor_cmd
  %r252 = call i64 @_list_new()
  store i64 %r252, i64* @actor_mailbox
  %r253 = call i64 @_list_new()
  store i64 %r253, i64* @actor_budget
  %r254 = call i64 @_list_new()
  store i64 %r254, i64* @actor_app
  %r255 = call i64 @_list_new()
  store i64 %r255, i64* @actor_file_buf
  %r256 = call i64 @_list_new()
  store i64 %r256, i64* @actor_target
  %r257 = call i64 @_list_new()
  store i64 %r257, i64* @wire_from
  %r258 = call i64 @_list_new()
  store i64 %r258, i64* @wire_to
  %r259 = sub i64 0, 1
  store i64 %r259, i64* @grabbed_node
  %r260 = sub i64 0, 1
  store i64 %r260, i64* @focused_node
  %r261 = sub i64 0, 1
  store i64 %r261, i64* @routing_node
  %r262 = sub i64 0, 1
  store i64 %r262, i64* @resizing_node
  %r263 = getelementptr [1 x i8], [1 x i8]* @.str.722, i64 0, i64 0
  %r264 = ptrtoint i8* %r263 to i64
  store i64 %r264, i64* @omni_text
  store i64 1, i64* @paradigm
  store i64 0, i64* @mouse_has_wheel
  store i64 3000, i64* @tcp_global_seq
  store i64 848382, i64* @rand_seed
  store i64 150, i64* @MAX_PARTS
  %r265 = call i64 @_list_new()
  store i64 %r265, i64* @part_x
  %r266 = call i64 @_list_new()
  store i64 %r266, i64* @part_y
  %r267 = call i64 @_list_new()
  store i64 %r267, i64* @part_vx
  %r268 = call i64 @_list_new()
  store i64 %r268, i64* @part_vy
  %r269 = call i64 @_list_new()
  store i64 %r269, i64* @part_life
  %r270 = call i64 @_list_new()
  store i64 %r270, i64* @vfs_name
  %r271 = call i64 @_list_new()
  store i64 %r271, i64* @vfs_start
  %r272 = call i64 @_list_new()
  store i64 %r272, i64* @vfs_size
    %os_res = call i64 @achlys_main()
    ret void
}
