set vb t_vb="
colorscheme xoria256
set lines=100 columns=400

" ----- Ubuntu GVim -----

" Use alt+hjkl to navigate between split windows
nnoremap <M-j>  <C-w>j
nnoremap <M-k>  <C-w>k
nnoremap <M-h>  <C-w>h
nnoremap <M-l>  <C-w>l

" Use alt+<>-= to resize split windows
nnoremap <M-,>  <C-w><
nnoremap <M-.>  <C-w>>
nnoremap <M-=>  <C-w>+
nnoremap <M-->  <C-w>-

" Use alt+# to switch to a certain numbered tab
" TODO use some number wildcard or for-loop instead of repeating mapping 9 times
nnoremap <M-1> 1gt
nnoremap <M-2> 2gt
nnoremap <M-3> 3gt
nnoremap <M-4> 4gt
nnoremap <M-5> 5gt
nnoremap <M-6> 6gt
nnoremap <M-7> 7gt
nnoremap <M-8> 8gt
nnoremap <M-9> 9gt
