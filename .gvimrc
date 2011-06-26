set vb t_vb="

" Maximize
set lines=100 columns=400

" Font on Mac
if has("unix")
    if system("uname") == "Darwin\n"
        "set guifont=Menlo:h12
        set guifont=Bitstream\ Vera\ Sans\ Mono:h13
    endif
endif

" Use alt+hjkl to navigate between split windows
nnoremap ∆  <C-w>j
nnoremap ˚  <C-w>k
nnoremap ˙  <C-w>h
nnoremap ¬  <C-w>l

" Use alt+<>-= to resize split windows
nnoremap ≤  <C-w><
nnoremap ≥  <C-w>>
nnoremap ≠  <C-w>+
nnoremap –  <C-w>-

" Use alt+# to switch to a certain numbered tab
" TODO use some number wildcard or for-loop instead of repeating mapping 9 times
nnoremap ¡ 1gt
nnoremap ™ 2gt
nnoremap £ 3gt
nnoremap ¢ 4gt
nnoremap ∞ 5gt
nnoremap § 6gt
nnoremap ¶ 7gt
nnoremap • 8gt
nnoremap ª 9gt
