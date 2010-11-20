
" TODO: Organize Andrew's stuff from bottom of file
" TODO: mappings for alt+hjkl for movement in insert mode
" TODO: get latex plugins


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
colorscheme desert

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

" Store temporary files in a central spot
" Check if the backup directory exists; if it doesn't, create it
set backupdir=~/.vim_backups//
silent execute '!mkdir -p ~/.vim_backups'
set directory=~/.vim_backups//

" Remember more history & undos
set history=1000
set undolevels=5000

" Persistent undo asdf
set undofile
set undodir=~/.vim_undos
set undoreload=10000

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
" The initial += is a bug workaround
set guioptions+=LlRrbT
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

" auto indent
set autoindent

" c-indentation
set cindent

" Expand tabs to spaces
set expandtab

" TODO: detect file and use different options. filetype indent?
set tabstop=4
set shiftwidth=4

" Automatically change directories when switching windows
set autochdir

" Incremental search when /
set incsearch

"set statusline=%M%R%l/%L\,%c:\%F
"
""To make it clearer which window i'm in i have a differently colored status line for the selected window.
"
"highlight StatusLine ctermfg=black ctermbg=green cterm=NONE
"
"highlight StatusLineNC ctermfg=black ctermbg=lightblue cterm=NONE

" {{{ Nice statusbar
"http://www.reddit.com/r/vim/comments/e19bu/whats_your_status_line/
"statusline setup
"set statusline=%f       "tail of the filename
"
""display a warning if fileformat isnt unix
"set statusline+=%#warningmsg#
"set statusline+=%{&ff!='unix'?'['.&ff.']':''}
"set statusline+=%*
"
""display a warning if file encoding isnt utf-8
"set statusline+=%#warningmsg#
"set statusline+=%{(&fenc!='utf-8'&&&fenc!='')?'['.&fenc.']':''}
"set statusline+=%*
"
"set statusline+=%h      "help file flag
"set statusline+=%y      "filetype
"set statusline+=%r      "read only flag
"set statusline+=%m      "modified flag
"
"" display current git branch
"set statusline+=%{fugitive#statusline()}
"
""display a warning if &et is wrong, or we have mixed-indenting
"set statusline+=%#error#
"set statusline+=%{StatuslineTabWarning()}
"set statusline+=%*
"
"set statusline+=%{StatuslineTrailingSpaceWarning()}
"
"set statusline+=%#warningmsg#
"set statusline+=%{SyntasticStatuslineFlag()}
"set statusline+=%*
"
""display a warning if &paste is set
"set statusline+=%#error#
"set statusline+=%{&paste?'[paste]':''}
"set statusline+=%*
"
"set statusline+=%=      "left/right separator
"set statusline+=%{StatuslineCurrentHighlight()}\ \ "current highlight
"set statusline+=%c,     "cursor column
"set statusline+=%l/%L   "cursor line/total lines
"set statusline+=\ %P    "percent through file
"set laststatus=2        " Always show status line
"
""return the syntax highlight group under the cursor ''
"function! StatuslineCurrentHighlight()
"    let name = synIDattr(synID(line('.'),col('.'),1),'name')
"    if name == ''
"        return ''
"    else
"        return '[' . name . ']'
"    endif
"endfunction
"
""recalculate the trailing whitespace warning when idle, and after saving
"autocmd cursorhold,bufwritepost * unlet! b:statusline_trailing_space_warning
"
""return '[\s]' if trailing white space is detected
""return '' otherwise
"function! StatuslineTrailingSpaceWarning()
"    if !exists("b:statusline_trailing_space_warning")
"        if search('\s\+$', 'nw') != 0
"            let b:statusline_trailing_space_warning = '[\s]'
"        else
"            let b:statusline_trailing_space_warning = ''
"        endif
"    endif
"    return b:statusline_trailing_space_warning
"endfunction
"
""return '[&et]' if &et is set wrong
""return '[mixed-indenting]' if spaces and tabs are used to indent
""return an empty string if everything is fine
"function! StatuslineTabWarning()
"    if !exists("b:statusline_tab_warning")
"        let tabs = search('^\t', 'nw') != 0
"        let spaces = search('^ ', 'nw') != 0
"
"        if tabs && spaces
"            let b:statusline_tab_warning =  '[mixed-indenting]'
"        elseif (spaces && !&et) || (tabs && &et)
"            let b:statusline_tab_warning = '[&et]'
"        else
"            let b:statusline_tab_warning = ''
"        endif
"    endif
"    return b:statusline_tab_warning
"endfunction
"
""return a warning for "long lines" where "long" is either &textwidth or 80 (if
""no &textwidth is set)
""
""return '' if no long lines
""return '[#x,my,$z] if long lines are found, were x is the number of long
""lines, y is the median length of the long lines and z is the length of the
""longest line
"function! StatuslineLongLineWarning()
"    if !exists("b:statusline_long_line_warning")
"        let long_line_lens = s:LongLines()
"
"        if len(long_line_lens) > 0
"            let b:statusline_long_line_warning = "[" .
"                        \ '#' . len(long_line_lens) . "," .
"                        \ 'm' . s:Median(long_line_lens) . "," .
"                        \ '$' . max(long_line_lens) . "]"
"        else
"            let b:statusline_long_line_warning = ""
"        endif
"    endif
"    return b:statusline_long_line_warning
"endfunction
"
""return a list containing the lengths of the long lines in this buffer
"function! s:LongLines()
"    let threshold = (&tw ? &tw : 80)
"    let spaces = repeat(" ", &ts)
"
"    let long_line_lens = []
"
"    let i = 1
"    while i <= line("$")
"        let len = strlen(substitute(getline(i), '\t', spaces, 'g'))
"        if len > threshold
"            call add(long_line_lens, len)
"        endif
"        let i += 1
"    endwhile
"
"    return long_line_lens
"endfunction
"
""find the median of the given array of numbers
"function! s:Median(nums)
"    let nums = sort(a:nums)
"    let l = len(nums)
"
"    if l % 2 == 1
"        let i = (l-1) / 2
"        return nums[i]
"    else
"        return (nums[l/2] + nums[(l/2)-1]) / 2
"    endif
"endfunction


" ------------------------------------------------------------------------------
" Vim Mappings
" ------------------------------------------------------------------------------

" Use comma for custom key-mapping first-character
"let mapleader=","
"let g:mapleader=","

" When just learning Vim, disable operation of arrow keys to forcibly adjust to
" using hjkl + normal mode
"noremap <Left>	<Nop>
"noremap <Right>	<Nop>
"noremap <Up>	<Nop>
"noremap <Down> <Nop>

" Use semicolon instead of colon to enter command mode.
noremap ; :
noremap : ;

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
" TODO: think of better shortcut keys. ctrl-j is too easily mistakenly pressed
"nnoremap <C-j> mz:m+<cr>`z
"nnoremap <C-k> mz:m-2<cr>`z
"vnoremap <C-j> :m'>+<cr>gv
"vnoremap <C-k> :m'<-2<cr>gv

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

" Set undo-points at newlines created in insert mode, to reduce undo step size
inoremap <Cr> <C-g>u<Cr>

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
nnoremap j  <C-w>j
nnoremap k  <C-w>k
nnoremap h  <C-w>h
nnoremap l  <C-w>l

" Use alt+<>-= to resize split windows
nnoremap ,  <C-w><
nnoremap .  <C-w>>
nnoremap =  <C-w>+
nnoremap -  <C-w>-



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
let Tlist_Show_One_File = 0

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

let g:yankring_enabled = 0  " Disables YankRing. I hate this plugin.
" Shortcut to display all entries in Yankring.
"nnoremap <silent> <F11> :YRShow<CR>

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

" ----- Hex Editing -----
" From http://vim.wikia.com/wiki/Improved_hex_editing
nnoremap <leader>x :Hexmode<CR>
"inoremap <C-H> <Esc>:Hexmode<CR>
"vnoremap <C-H> :<C-U>Hexmode<CR>
" ex command for toggling hex mode - define mapping if desired
command -bar Hexmode call ToggleHex()

" helper function to toggle hex mode
function! ToggleHex()
  " hex mode should be considered a read-only operation
  " save values for modified and read-only for restoration later,
  " and clear the read-only flag for now
   setlocal noeol
"  let l:modified=&mod
"  let l:oldreadonly=&readonly
"  let &readonly=0
"  let l:oldmodifiable=&modifiable
"  let &modifiable=1
  if !exists("b:editHex") || !b:editHex
    " save old options
"    let b:oldft=&ft
"    let b:oldbin=&bin
"    " set new options
"    setlocal binary " make sure it overrides any textwidth, etc.
"    let &ft="xxd"
    " set status
    let b:editHex=1
    " switch to hex editor
    %!xxd -c4
  else
    " restore old options
"    let &ft=b:oldft
"    if !b:oldbin
"      setlocal nobinary
"    endif
    " set status
    let b:editHex=0
    " return to normal editing
    %!xxd -r
  endif
  " restore values for modified and read only state
"  let &mod=l:modified
"  let &readonly=l:oldreadonly
"  let &modifiable=l:oldmodifiable
endfunction



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


" TODO: use make
" ----- C++ -----
" F2 to compile; F3 to run
function! EnterCpp()
  map <special> <F2> :w<CR>:!clear;g++ -Wall %<CR>
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

" ----- TeX -----
" F2 to run
function! EnterTex()
  noremap <buffer> <F2> :w<CR>:!pdflatex % <CR>
endfunction
au Filetype tex call EnterTex()

" Automatically make files beginning with a bang-path executable
if has("unix")
    autocmd BufWritePost *
                \   if getline(1) =~ "^#!"            |
                \       if getline(1) =~ "/bin/"      |
                \           silent !chmod +x <afile>; |
                \       endif                         |
                \   endif
endif


" ------------------------------------------------------------------------------
" Andrew's vimrc + Google
" ------------------------------------------------------------------------------

"set cinoptions=l1,g0.5s,h0.5s,i2s,+2s,(0,W2s
" Make sure that the tab key actually inserts a tab.
" imap <TAB> <C-V><TAB>

" Nice helper stuff:
set showmode
set showmatch
set ruler
set showcmd
"set hlsearch        " Highlight previous search results
set backspace=2
"set visualbell
"set nowrap
set textwidth=0

" Tab-complete filenames to longest unambiguous match and present menu:
set wildmenu wildmode=longest:full


" Jump to last location when re-opening file
:au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g'\"" | endif


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


" Autoload commands:
if has("autocmd")
  " When editing a file, always jump to the last cursor position
  autocmd BufReadPost * if line("'\"") | exe "'\"" | endif
endif


" Andrew's stuff
"set textwidth=0 "Disable auto-wrapping when you type
set tw=0 "Disable auto-wrapping when you type
set background=dark


" Enable plugin ragtag.vim
let g:ragtag_global_maps = 1

"function! EnterCpp()
"	map <buffer> <F2> :w<CR>:!clear;g++ -Wall %
	"map <buffer> <F3> :!clear;./a.out
	"let b:comment_prefix = '//'
	"endfunction
"au FileType cpp call EnterCpp()
"
