
" ------------------------------------------------------------------------------
" Vim Settings
" ------------------------------------------------------------------------------

" This option should be the first. It may override other settings, such as
" This setting prevents Vim from emulating the original vi's bugs and
" limitations.
" set iskeyword
set nocompatible

" Syntax highlighting
syntax on

" Set colour scheme. Wombat is a third-party colorscheme. Also good: ir_black
" (third-party), desert (comes by default)
colorscheme wombat

" Allow filetype-specific plugins, such as matchit
filetype plugin on

" Have Vim automatically reload changed files on disk. Very useful when using
" git and switching between branches
set autoread

" Automatically write buffers to file when current window switches to another
" buffer as a result of :next, :make, etc. See :h autowrite.
set autowrite

" Keep more lines on-screen when scrolling up/down
set scrolloff=5

" Caps in /find and s/// will invoke case-sensitive matching; otherwise,
" case-insensitive matching
set ignorecase
set smartcase

" Line numbers
set number

" Remember more history & undos
set history=1000
set undolevels=5000

" Store temporary files in a central spot
" Check if the backup directory exists; if it doesn't, create it
set backupdir=~/.vim_backups//
silent execute '!mkdir -p ~/.vim_backups'
set directory=~/.vim_backups//

" Highlight search results and map <Space> to turn off
set hlsearch
nnoremap <silent> <ESC> :noh<cr><ESC>
"nnoremap <silent> <space> :set hls!<cr>  "Toggles, but is not automatically set on when searching again

" Smart '>' & '<' indentation! With 3 spaces, press '>', insert 1 space, not 4.
set shiftround

" Improve autocomplete menu behaviour:
" - Still display autocomplete menu if there's only one match
" - Show extra info about match (such as which file it's found in)
set completeopt=menuone,preview

" Turn off visual bell
set vb t_vb=

" Gvim turn off scrollbars and other unnecessary menu items
set guioptions-=LlRrbT

" Disallow menu access using the Alt key
set winaltkeys=no

" GVim font
"set guifont=Bitstream\ Vera\ Sans\ Mono\ 10.7

" Minimum width and height of window containing cursor
set winheight=30
set winwidth=85

" Set command window height to reduce number of 'Press ENTER...' prompts
set cmdheight=2

" Horizontal line indicating cursor position
" This is disabled because it slows down cursor movements, especially with multi-line lines
"set cursorline

" Better window splitting start locations
set splitbelow
set splitright

" Lets vim set the title of the console
set title

" Allow mouse to be used. Works on Ubuntu gvim AND terminal vim; not on Mac
set mouse=a


" ------------------------------------------------------------------------------
" Vim Mappings
" ------------------------------------------------------------------------------

" When just learning Vim, disable operation of arrow keys to forcibly adjust to
" using hjkl
"noremap <Left>	<Nop>
"noremap <Right>	<Nop>
"noremap <Up>	<Nop>
"noremap <Down> <Nop>

" Use semicolon instead of colon to enter command mode.
noremap ; :

" Visual-mode indentation shifting: don't de-select after shift, keep selected.
vnoremap < <gv
vnoremap > >gv

" Paste with respect to current line's indent. Will be overriden by Yankring.
nnoremap P [p
nnoremap p ]p

" Scroll down/up in insert mode without displacing cursor
inoremap <C-y> <C-o><C-y>
inoremap <C-e> <C-o><C-e>

" Move a line of text using ctrl+[jk]
nnoremap <C-j> mz:m+<cr>`z
nnoremap <C-k> mz:m-2<cr>`z
vnoremap <C-j> :m'>+<cr>gv
vnoremap <C-k> :m'<-2<cr>gv

" Shortcuts for system clipboard access: works in Ubuntu gvim & terminal vim.
" Does not work in Mac. Will be overwritten by Yankring
noremap gp "+]p
noremap gP "+[P
vnoremap gy "+y
vnoremap gY "+Y

" Ctrl-tab to switch next/prev tab, like in FireFox, Chrome, etc.
nnoremap <silent><C-S-Tab> :tabp<CR>
nnoremap <silent><C-Tab> :tabn<CR>

" Ctrl-s for smart saving. (Don't write to file if no changes)
nnoremap <silent><C-s> :update<Cr>
inoremap <silent><C-s> <Esc>:update<Cr>

" Jump to beginning and end of brace-surrounded blocks
noremap [[ [{
noremap ]] ]}

" Ctrl+Backspace to backspace a word
inoremap <C-BS> <C-W>

" When jumping to mark, jump directly to the correct column as well as line
noremap ' `

" Yank to end of line
noremap Y y$

" Closing brace auto-inserted upon pressing { in insert mode
" TODO: This should be more sophisticated, preferrably scripted instead of
" simple mapping
inoremap {<CR> {<CR>}<Left><CR><Up><Tab>
inoremap {<Space> {<Space><Space>};<Left><Left><Left>
inoremap {;<CR> {<Esc>o};<Esc>O

" let [jk] go down and up by display lines instead of real lines. Let g[jk]
" do what [jk] normally does
nnoremap k gk
nnoremap j gj
nnoremap gk k
nnoremap gj j

" Key mappings for window switching. To map the alt key (aka meta key) in some
" TODO: Detect what vim is running on, and conditionally map keys.

" ----- Mac Terminal Vim -----

" Use alt+hjkl to navigate between split windows
"nnoremap ∆  <C-w>j
"nnoremap ˚  <C-w>k
"nnoremap ˙  <C-w>h
"nnoremap ¬  <C-w>l
"
"" Use alt+<>-= to resize split windows
"nnoremap ≤  <C-w><
"nnoremap ≥  <C-w>>
"nnoremap ≠  <C-w>+
"nnoremap –  <C-w>-

" ----- Ubuntu Terminal Vim -----

" Use alt+hjkl to navigate between split windows
"nnoremap j  <C-w>j
"nnoremap k  <C-w>k
"nnoremap h  <C-w>h
"nnoremap l  <C-w>l
"
"" Use alt+<>-= to resize split windows
"nnoremap ,  <C-w><
"nnoremap .  <C-w>>
"nnoremap =  <C-w>+
"nnoremap -  <C-w>-

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


" ------------------------------------------------------------------------------
" Plugin Settings and Mappings
" ------------------------------------------------------------------------------

" ----- Taglist -----
" TODO: Set up Nathan's ctags script

" Toggles Taglist sidebar
noremap <silent> <Leader>tl	:TlistToggle<CR>

" Taglist window options
let Tlist_Auto_Open = 1
let Tlist_Use_Right_Window = 1
let Tlist_WinWidth = 30
let Tlist_Exit_OnlyWindow = 1
let Tlist_Show_One_File = 1

" Show functions, methods, classes, and global variables in JavaScript
let tlist_javascript_settings = 'javascript;f:function;m:method;c:constructor;v:variable'

" ----- SuperTab -----
" Default completion type is <c-p>
"let g:SuperTabDefaultCompletionType = 'context'

" ----- AutoComplPop -----
" Disable and use SuperTab instead (slows typing a bit over NX Ubiquity)
"au VimEnter * AcpDisable

" ----- Yankring -----
" NOTE: This plugin may override custom yank and paste mappings.

" Shortcut to display all entries in Yankring.
nnoremap <silent> <F11> :YRShow<CR>

" ----- NERD Commenter -----
" Toggles comment state of selected lines.
nnoremap gc ,c<Space>
vnoremap gc ,c<Space>

" ----- FuzzyFinder -----
" Do not disable any modes
let g:fuf_modesDisable = []

" Most recently used file & command list max size
let g:fuf_mrufile_maxItem = 300
let g:fuf_mrucmd_maxItem = 400

" Key mappings: all prefixed by Ctrl-f
nnoremap <silent> <C-f>b     :FufBuffer<CR>
nnoremap <silent> <C-f>d     :FufFileWithCurrentBufferDir<CR>
nnoremap <silent> <C-f>w 	   :FufFileWithFullCwd<CR>
nnoremap <silent> <C-f>f     :FufFile<CR>
nnoremap <silent> <C-f>m     :FufMruFile<CR>
nnoremap <silent> <C-f>c     :FufMruCmd<CR>
nnoremap <silent> <C-f>k     :FufBookmark<CR>
nnoremap <silent> <C-f>t     :FufTag<CR>
nnoremap <silent> <C-f>l     :FufLine<CR>
nnoremap <silent> <C-f>h     :FufHelp<CR>
nnoremap <silent> <C-f>e     :FufEditInfo<CR>

" ----- JavaScript Syntax File -----
let javascript_enable_domhtmlcss=1

" ----- CamelCase -----
" By default, ',w', ',b', ',e' are mapped
"" Map wbe to camel case motions from camelcase script
"map <silent> b <Plug>CamelCaseMotion_b
"map <silent> w <Plug>CamelCaseMotion_w
"map <silent> e <Plug>CamelCaseMotion_e
"sunmap w
"sunmap b
"sunmap e

" ----- NERDTree -----
" \nt Toggles NERDTree file browser sidebar
noremap <silent> <Leader>nt	:NERDTreeToggle<CR>

" Open NERDTree sidebar upon Vim startup
"au VimEnter * NERDTree

" ----- Trailing Whitespace -----
" Remove trailing whitespace on save
function! StripTrailingWhitespace()
  silent exe "normal mz<CR>"
  let saved_search = @/
  %s/\s\+$//e
  silent exe "normal `z<CR>"
  let @/ = saved_search
endfunction
au BufWritePre * call StripTrailingWhitespace()

" ----- Automatic Session Saving -----
" From http://vim.wikia.com/wiki/Go_away_and_come_back
" Automatically load and save session on start/exit.
"function! MakeSession()
"  if g:sessionfile != ""
"    echo "Saving."
"    if (filewritable(g:sessiondir) != 2)
"      exe 'silent !mkdir -p ' g:sessiondir
"      redraw!
"    endif
"    exe "mksession! " . g:sessionfile
"  endif
"endfunction
"
"function! LoadSession()
"  if argc() == 0
"    let g:sessiondir = $HOME . "/.vim/sessions" . getcwd()
"    let g:sessionfile = g:sessiondir . "/session.vim"
"    if (filereadable(g:sessionfile))
"      exe 'source ' g:sessionfile
"    else
"      echo "No session loaded."
"    endif
"  else
"    let g:sessionfile = ""
"    let g:sessiondir = ""
"  endif
"endfunction
"
"au VimEnter * call LoadSession()
"au VimLeave * call MakeSession()


" ------------------------------------------------------------------------------
" Filetype Handling
" ------------------------------------------------------------------------------

" ----- JavaScript -----
function! EnterJavaScript()
    " Integrate JSLint as make program
    set makeprg=/home/davidhu/jslintvim
    set errorformat=%f:%l\\,\ E:%n:\ %m

    " Invoke JSLint on buffer(s) with shortcut key
    noremap <buffer><F2> <Esc>:!clear<Cr>:up \| make %:p<Cr>
    noremap <buffer><F3> <Esc>:!clear<Cr>:wa \| make<Cr>
endfunction
au Filetype javascript call EnterJavaScript()

" JavaScript folding
" Mappings and function from http://amix.dk/vim/vimrc.html
"let b:javascript_fold=1
"au FileType javascript call JavaScriptFold()
"au filetype javascript setl fen
"function! JavaScriptFold()
"    setl foldlevelstart=1
"    setl foldmethod=syntax
"    syn region foldBraces start=/{/ end=/}/ transparent fold keepend extend
"
"    function! FoldText()
"    return substitute(getline(v:foldstart), '{.*', '{...}', '')
"    endfunction
"    setl foldtext=FoldText()
"endfunction


" ----- C++ -----
" F2 to compile; F3 to run
function! EnterCpp()
  map <buffer> <F2> :w<CR>:!clear;g++ -Wall %<CR>
  map <buffer> <F3> :!./a.out<CR>
endfunction
au Filetype cpp call EnterCpp()

" ----- C -----
" F2 to compile; F3 to run
function! EnterC()
  map <buffer> <F2> :w<CR>:!clear;gcc -Wall %<CR>
  map <buffer> <F3> :!./a.out<CR>
endfunction
au Filetype c call EnterC()

" ----- Scheme -----
" F2 to to run
function! EnterScheme()
  map <buffer> <F2> :w<CR>:!clear;mzscheme %<CR>
endfunction
au Filetype scheme call EnterScheme()


" ------------------------------------------------------------------------------
" Andrew's vimrc + Google
" ------------------------------------------------------------------------------

"source /home/build/public/eng/vim/google.vim

" Attempt to get sane indenting:
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set cinoptions=l1,g0.5s,h0.5s,i2s,+2s,(0,W2s
" Make sure that the tab key actually inserts a tab.
" imap <TAB> <C-V><TAB>

" Nice helper stuff:
set showmode
set showmatch
set ruler
set showcmd
set incsearch
"set hlsearch        " Highlight previous search results
set backspace=2
"set visualbell
"set nowrap
set textwidth=0

" Tab-complete filenames to longest unambiguous match and present menu:
set wildmenu wildmode=longest:full


" Highlights lines that are too long
"func! HighlightLongLines()
"  highlight def link RightMargin Error
"  exec 'match RightMargin /\%<' . (83) . 'v.\%>' . (81) . 'v/'
"endfun

"augroup filetypedetect
"  au BufNewFile,BufRead * call HighlightLongLines()
"augroup END


" Jump to last location when re-opening file
:au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g'\"" | endif


" Read Perforce //depot paths
autocmd BufReadCmd //depot/* exe "0r !v4 print -q <afile>"
autocmd BufReadCmd //depot/* 1
autocmd BufReadCmd //depot/* set readonly


" Some nice shortcuts:
" Reformat lines.
map Q gq
" Enter/leave paste mode.
"map gp :set invpaste<CR>:set paste?<CR>
" Edit alternate file.
"map gg :e#<CR>
" Turn on word-wrapping.
"map gw :se tw=75<CR>
" Execute contents of register q
map \ @q
" Get rid of trailing whitespace.
map gw :%s/[ <Tab>]\+$//<CR>

" Fix paragraph movement ('{' and '}') to ignore whitespace.
" (This mostly works correctly, except when used in selection ('V') mode,
"  where the last search is changed.)
"nmap <silent>{ ?\S?;?^\s*$<CR>:call histdel("search", -1)<CR>:let @/ = histget("search", -1)<CR>:noh<CR>
"omap <silent>{ ?\S?;?^\s*$<CR>:call histdel("search", -1)<CR>:let @/ = histget("search", -1)<CR>:noh<CR>
""vmap <silent>{ ?\S?;?^\s*$<CR>
"nmap <silent>} /\S/;/^\s*$<CR>:call histdel("search", -1)<CR>:let @/ = histget("search", -1)<CR>:noh<CR>
"omap <silent>} /\S/;/^\s*$<CR>:call histdel("search", -1)<CR>:let @/ = histget("search", -1)<CR>:noh<CR>
"vmap <silent>} /\S/;/^\s*$<CR>

" Autoload commands:
if has("autocmd")
  " When editing a file, always jump to the last cursor position
  autocmd BufReadPost * if line("'\"") | exe "'\"" | endif
endif



" make helpers
let workdir = getcwd()
let g3root = matchstr(getcwd(), ".*google3")
au QuickFixCmdPre make execute ':cd' . g3root
au QuickFixCmdPost make execute ':cd' . workdir
set makeprg=blaze\ $*


" perforce commands
command! -nargs=* -complete=file PEdit :!v4 edit "%"
"command! -nargs=* -complete=file PEdit :!if [[ "%" =~ "/google/code/" ]]; then v4 edit "%"; else g4 edit "%"; fi
command! -nargs=* -complete=file PRevert :!v4 revert %
command! -nargs=* -complete=file PDiff :!v4 diff %

function! s:CheckOutFile()
  if filereadable(expand("%")) && ! filewritable(expand("%"))
    let option = confirm("Readonly file, do you want to checkout?"
             \, "&Yes\n&No", 1, "Question")
    if option == 1
      PEdit
    endif
    edit!
  endif
endfunction
au FileChangedRO * nested :call <SID>CheckOutFile()

" Andrew's stuff
"set autochdir
"set textwidth=0 "Disable auto-wrapping when you type
set tw=0 "Disable auto-wrapping when you type
set background=dark


" open new line with alt+o
inoremap <M-o>       <Esc>o

" so we can undo newlines
" this mapping below does not work right now (the output part)
"inoremap 	<Esc>o

" Enable plugin ragtag.vim
let g:ragtag_global_maps = 1

" perforce commands
command! -nargs=* -complete=file PEdit :!g4 edit %
command! -nargs=* -complete=file PRevert :!g4 revert %
command! -nargs=* -complete=file PDiff :!g4 diff %

function! s:CheckOutFile()
 if filereadable(expand("%")) && ! filewritable(expand("%"))
   let s:pos = getpos('.')
   let option = confirm("Readonly file, do you want to checkout from p4?"
         \, "&Yes\n&No", 1, "Question")
   if option == 1
     PEdit
   endif
   edit!
   call cursor(s:pos[1:3])
 endif
endfunction
au FileChangedRO * nested :call <SID>CheckOutFile()


"function! EnterCpp()
"	map <buffer> <F2> :w<CR>:!clear;g++ -Wall %
	"map <buffer> <F3> :!clear;./a.out
	"let b:comment_prefix = '//'
	"endfunction
"au FileType cpp call EnterCpp()
"
