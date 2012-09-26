
" TODO: mappings for alt+hjkl for movement in insert mode
" TODO: get latex plugins
" TODO: turn off matchparen for certain files for faster scrolling
" TODO: Move file-specific stuff near the bottom to .vim/ftplugin


" ------------------------------------------------------------------------------
" Vim Settings
" ------------------------------------------------------------------------------

" This option should be the first. It may override other settings, such as
" This setting prevents Vim from emulating the original vi's bugs and
" limitations.
" set iskeyword
set nocompatible

" Required for Vundle - https://github.com/gmarik/vundle
filetype off
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" ----- Plugins managed by Vundle -----
Bundle 'gmarik/vundle'
Bundle 'tpope/vim-fugitive'
Bundle 'The-NERD-Commenter'
" Bundle 'rstacruz/sparkup', {'rtp': 'vim/'}
"Bundle 'divad12/sparkup', {'rtp': 'vim/'}
Bundle 'scrooloose/nerdtree'
Bundle 'a.vim'
Bundle 'ctags.vim'
Bundle 'taglist-plus'
Bundle 'SuperTab-continued.'
Bundle 'matchit.zip'
Bundle 'ragtag.vim'
Bundle 'surround.vim'
Bundle 'repeat.vim'
Bundle 'pyflakes'
Bundle 'Gundo'
Bundle 'Syntastic'
Bundle 'css_color.vim'
Bundle 'HTML5-Syntax-File'
Bundle 'kien/ctrlp.vim'
Bundle 'nathanaelkane/vim-indent-guides'
Bundle 'Lokaltog/vim-powerline'
Bundle 'delimitMate.vim'
Bundle 'TaskList.vim'
Bundle 'felixge/vim-nodejs-errorformat'
Bundle 'EasyGrep'
Bundle 'gregsexton/MatchTag'
Bundle 'tpope/vim-abolish'
Bundle 'Shougo/neocomplcache'
Bundle 'python_match.vim'
Bundle 'nono/vim-handlebars'
Bundle 'IndexedSearch'
Bundle 'phleet/vim-arcanist'
Bundle 'flxf/uCpp.vim'

" Color schemes
Bundle 'Solarized'
Bundle 'xoria256.vim'
Bundle 'Mustang2'
Bundle 'molokai'
Bundle 'Wombat'
Bundle 'chriskempson/tomorrow-theme', {'rtp': 'vim/'}


" Syntax highlighting
syntax on

" Set colour scheme. Wombat is a third-party colorscheme. Also good: ir_black
" molokai, xoria256, desert (comes by default). For some reason, solarized
" doesn't work well in normal terminal vim...
set background=dark
set t_Co=256
colorscheme xoria256

" Allow filetype-specific plugins, such as matchit
filetype plugin indent on

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

" Remember more history
set history=1000
set undolevels=5000

" Persistent undo
if has("persistent_undo")
  set undofile
  set undodir=~/.vim_undos
  set undoreload=10000
endif

" Incremental search when /
set incsearch

" Highlight search results and map <Space> to turn off
set hlsearch
nnoremap <silent> <Space> :nohlsearch<cr><ESC>
"nnoremap <silent> <space> :set hls!<cr>  "Toggles, but is not automatically set on when searching again

" Improve autocomplete menu behaviour:
" - Still display autocomplete menu if there's only one match
" - Show extra info about match (such as which file it's found in)
set completeopt=menuone,preview

" Turn off visual bell
autocmd VimEnter * set vb t_vb=

" Gvim turn off scrollbars and other unnecessary menu items
" The initial += is a bug workaround
set guioptions+=LlRrbT
set guioptions-=LlRrbT

" Disallow menu access using the Alt key
set winaltkeys=no

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

" Indentation
" TODO: detect file and use different options. filetype indent?
set autoindent
set cindent
set expandtab  " Expand tabs to spaces
set copyindent " Copy previous line's indent style
set tabstop=2
set shiftwidth=2
set softtabstop=2

" Smart '>' & '<' indentation! With 3 spaces, press '>', insert 1 space, not 4.
set shiftround

" Wrap comments at 80
set textwidth=80

" Show current mode (insert, visual, normal, etc.)
set showmode

" Show matching paren. This sometimes causes lag.
set showmatch

" Show line and column number
set ruler

" Show last command in status line
set showcmd

" Automatically change directories when switching windows
if has("netbeans_intg") || has("sun_workshop")
  set autochdir
endif

" Disable console vim from attepting to connect to the X display, which may
" slow things down for a few seconds
set cb="exclude:.*"

" This will look in the current directory for 'tags', and work up the tree
" towards root until one is found.
" From: http://stackoverflow.com/questions/563616/vim-and-ctags-tips-and-tricks
set tags=tags;/

" Tell vim to remember certain things when we exit
"  '10 : marks will be remembered for up to 10 previously edited files
"  "100 : will save up to 100 lines for each register
"  :20 : up to 20 lines of command-line history will be remembered
"  % : saves and restores the buffer list
"  n... : where to save the viminfo files
set viminfo='10,\"100,:20,%,n~/.viminfo

" Always display a status line
set laststatus=2

" Allow backspacing over indent, eol, and start of insert
set backspace=2

" Hide buffers instead of unloading them
set hidden

" I don't use modula2 nearly as much as markdown
au BufRead,BufNewFile *.md		set filetype=markdown

" Add HiveQL script extension
au BufRead,BufNewFile *.q set filetype=sql

" Add "-" to be a keyword character for autocomplete and * and # searches
" (useful for html IDs for example)
"au InsertEnter * set isk+=-
"au InsertLeave * set isk-=-
set iskeyword+=-

" From :h encoding: For MacVim and GTK+ 2 it is highly recommended to set 'encoding' to "utf-8".
set encoding=utf-8

" Custom invisible character characters
set listchars=tab:▸\ ,eol:¬,extends:❯,precedes:❮,trail:.

" :h lazyredraw: the screen will not be redrawn while executing macros.... Also, updating the window title is postponed.
set lazyredraw

" Tenths of seconds matching paren is blink-highlighted (default is 5)
set matchtime=3

" String to put at the start of lines that have been wrapped.
set showbreak=↪

" Tab-complete filenames to longest unambiguous match and present menu
set wildmenu wildmode=longest:full
set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/.vim_backups/*
set wildignore+=*.aux,*.out,*.toc                " LaTeX intermediate files
set wildignore+=*.jpg,*.bmp,*.gif,*.png,*.jpeg   " binary images
set wildignore+=*.o,*.d,*.obj,*.exe,*.dll,*.manifest,*.class " compiled object files
set wildignore+=*.spl                            " compiled spelling word lists
set wildignore+=*.sw?                            " Vim swap files
set wildignore+=*.DS_Store                       " OSX bullshit
set wildignore+=*.pyc                            " Python byte code

" Wrap comments at textwidth (but not code), recognize numbered lists, and other formatting options
set formatoptions=crqn1

" Highlight the forbidden column
if exists("+colorcolumn")
  set colorcolumn=+1
endif

" Show the corresponding unicode characters of some TeX markup for fancy display
set conceallevel=2
let g:tex_conceal="admg"


" ------------------------------------------------------------------------------
" Vim Mappings
" ------------------------------------------------------------------------------

" Use comma for first key of some custom mappings
let mapleader=","
let maplocalleader=","

" Use semicolon instead of colon to enter command mode.
noremap ; :
noremap : ;

" Visual-mode indentation shifting: don't de-select after shift, keep selected.
vnoremap < <gv
vnoremap > >gv

" Paste with respect to current line's indent. Will be overriden by Yankring.
nnoremap P [p
nnoremap p ]p
nnoremap [p P
nnoremap ]p P

" Scroll down/up in insert mode without displacing cursor
inoremap <C-y> <C-o><C-y>
"inoremap <C-e> <C-o><C-e>  " Conflicts with sparkup

" Shortcuts for system clipboard access: works in Ubuntu gvim, terminal vim, macvim.
nnoremap gp "+]p
nnoremap gP "+[P
vnoremap gp d"+]p
vnoremap gP d"+[P
vnoremap gy "+y
vnoremap gY "+Y

" Ctrl-s for save all changed buffers.
nnoremap <silent><C-s> :wa<Cr>
inoremap <silent><C-s> <Esc>:wa<Cr>

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
"inoremap {<CR> {<CR>}<Left><CR><Up><Tab>
"inoremap {<Space> {<Space><Space>};<Left><Left><Left>
"inoremap {;<CR> {<Esc>o};<Esc>O

" let [jk] go down and up by display lines instead of real lines. Let g[jk]
" do what [jk] normally does
nnoremap k gk
nnoremap j gj
nnoremap gk k
nnoremap gj j

" ^K is a very annoying mapping that brings up the man page of the cursor
" under the word. Times I've needed it: 0. Remap to opposite of ^J: insert new line
nnoremap K mzo<Esc>`z

" Set undo-points at newlines created in insert mode, to reduce undo step size
" TODO: For some reason this creates two newlines instead of one
"inoremap <Cr> <C-g>u<Cr>

" Use ctrl+hjklnp to navigate between split windows and tabs
nnoremap <C-j>  <C-w>j
nnoremap <C-k>  <C-w>k
nnoremap <C-h>  <C-w>h
nnoremap <C-l>  <C-w>l
nnoremap <C-n>  gt
nnoremap <C-p>  gT

" Use s as a d,y,c modifier to grab a brace-delimited class
onoremap s normal:k][[[kV][j<CR>

" When editing file requiring root privileges, but forgot to sudo
cnoremap w!! w !sudo tee % >/dev/null

" Format an XML doc. From http://uucode.com/blog/2005/06/15/indenting-xml-in-vim/
nnoremap <leader>x <Esc>:1,$!xmllint --format -<CR>

" Keep search matches in the middle of the window
nnoremap n nzz
nnoremap N Nzz

" Open a Quickfix window for the last search.
nnoremap <silent> <leader>/ :execute 'vimgrep /'.@/.'/g %'<CR>:copen<CR>

" 'Inside-line' operator-pending-mode mapping (new text object)
onoremap <silent> il :<C-U>normal! ^v$h<CR>
onoremap <silent> iL :<C-U>normal! 0v$h<CR>

" save, make, and show quickfix window on error
nnoremap <Leader><Leader> :w<CR>:make! \| botright cwindow<CR>


" ------------------------------------------------------------------------------
" Plugin Settings and Mappings
" ------------------------------------------------------------------------------

" ----- Taglist -----
" TODO: Set up Nathan's ctags script

" Toggles Taglist sidebar
noremap <silent> <Leader>tl	:TlistToggle<CR>

" Taglist window options
"let Tlist_Auto_Open = 1
let Tlist_Use_Right_Window = 1
"let Tlist_WinWidth = 30
let Tlist_Exit_OnlyWindow = 1
let Tlist_Show_One_File = 1

" Show functions, methods, classes, and global variables in JavaScript
"let tlist_javascript_settings = 'javascript;f:function;m:method;c:constructor;v:variable'

" ----- SuperTab -----
" Default completion type is <c-p>
"let g:SuperTabDefaultCompletionType = '<c-n>'
"let g:SuperTabDefaultCompletionType = '<c-x><c-u>'
let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabLongestHighlight = 1

" ----- NERD Commenter -----
" Toggles comment state of selected lines.
" TODO: Why don't mappings below work. Gross hack below.
"nnoremap gc <plug>NERDCommenterToggle
"vnoremap gc <plug>NERDCommenterToggle
nmap gc <leader>c<space>
vmap gc <leader>c<space>

" ----- Pyflakes -----
autocmd FileType python map <buffer> <F3> :call Pyflakes()<CR>

" ----- Gundo -----
nnoremap <leader>gd :GundoToggle<CR>

" ----- Syntastic -----
let g:syntastic_enable_signs=1
let g:syntastic_auto_loc_list=0
let g:syntastic_javascript_checker = "jshint"

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
let NERDTreeIgnore=['\.o$', '\~$', '\.pyc$']

" Use arrows instead of the `+` and `~`, and '|' characters
let g:NERDTreeDirArrows=1

" ----- ragtag -----
let g:ragtag_global_maps = 1

" ----- Sparkup -----
" let g:sparkup = '$HOME/.vim/bundle/sparkup/sparkup'

" Open NERDTree sidebar upon Vim startup
"au VimEnter * NERDTree

" ----- ctrlp.vim -----
let g:ctrlp_mru_files = 1

" This will jump to a file that is already in an opened buffer if it is in another tab.
let g:ctrlp_jump_to_buffer = 2

" Always use regex search instead of fuzzy string matching
let g:ctrlp_regexp_search = 1

" Search by filename, not full path
let g:ctrlp_by_filename = 1

" Custom mappings
let g:ctrlp_map = '<leader>f'
nnoremap <silent> <leader>b :CtrlPBuffer<CR>
nnoremap <silent> <leader>m :CtrlPMRUFiles<CR>

" ----- Indent Guides -----
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_color_change_percent = 3
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
nnoremap <leader>i :IndentGuidesToggle<CR>

" ----- Powerline -----
if has("unix") && system("uname") == "Darwin\n"
  let g:Powerline_symbols = 'fancy'
endif

" ----- Eclim -----
" Don't show todo markers in margin
let g:EclimSignLevel = 2

" ----- neocomplcache -----
" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Use camel case completion.
let g:neocomplcache_enable_camel_case_completion = 1
" Use underbar completion.
let g:neocomplcache_enable_underbar_completion = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
"let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'
" Force use neocomplcache's completion functions
let g:neocomplcache_force_overwrite_completefunc = 1

" ---- C-support ----
let g:C_Styles = { '*.c,*.h' : 'default', '*.cc,*.cpp,*.hh' : 'CPP' }

" ----- Trailing Whitespace -----
" Remove trailing whitespace on save
function! StripTrailingWhitespace()
 silent exe "normal mz<CR>"
 let saved_search = @/
 %s/\s\+$//e
 silent exe "normal `z<CR>"
 let @/ = saved_search
endfunction
"au BufWritePre * call StripTrailingWhitespace()
nnoremap <silent><leader>tw :call StripTrailingWhitespace()<Cr>

"" but disable tab special chars in certain files
"autocmd filetype html,xml,Makefile set listchars-=tab:>.

" Highlight trailing whitespace - http://vim.wikia.com/wiki/Highlight_unwanted_spaces
highlight ExtraWhitespace ctermbg=red guibg=red
au ColorScheme * highlight ExtraWhitespace guibg=red
au BufEnter * match ExtraWhitespace /\s\+$/
au InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
au InsertLeave * match ExtraWhiteSpace /\s\+$/

let c_space_errors = 1
let java_space_errors = 1
let cpp_space_errors = 1
let python_space_errors = 1
let ruby_space_errors = 1


" ----- Hex Editing -----
" From http://vim.wikia.com/wiki/Improved_hex_editing
nnoremap <leader>x :Hexmode<CR>
"inoremap <C-H> <Esc>:Hexmode<CR>
"vnoremap <C-H> :<C-U>Hexmode<CR>
" ex command for toggling hex mode - define mapping if desired
command! -bar Hexmode call ToggleHex()

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

" ----- Hg Blame -----
" From https://bitbucket.org/sjl/dotfiles/src/tip/vim/.vimrc
function! s:HgBlame()
    let fn = expand('%:p')

    wincmd v
    wincmd h
    edit __hgblame__
    vertical resize 28

    setlocal scrollbind winfixwidth nolist nowrap nonumber buftype=nofile ft=none

    normal ggdG
    execute "silent r!hg blame -undq " . fn
    normal ggdd
    execute ':%s/\v:.*$//'

    wincmd l
    setlocal scrollbind
    syncbind
endf
command! -nargs=0 HgBlame call s:HgBlame()
nnoremap <leader>hb :HgBlame<cr>

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
" Autocommands / Filetype Handling
" ------------------------------------------------------------------------------

" Jump to last location when re-opening file
au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g'\"" | endif

" Autoload commands:
if has("autocmd")
  " When editing a file, always jump to the last cursor position
  autocmd BufReadPost * if line("'\"") | exe "'\"" | endif
endif

" ----- JavaScript -----
"function! EnterJavaScript()
"    " Integrate JSLint as make program
"    set makeprg=/home/davidhu/jslintvim
"    set errorformat=%f:%l\\,\ E:%n:\ %m
"
"    " Invoke JSLint on buffer(s) with shortcut key
"    noremap <buffer><F2> <Esc>:!clear<Cr>:up \| make %:p<Cr>
"    noremap <buffer><F3> <Esc>:!clear<Cr>:wa \| make<Cr>
"endfunction
"au Filetype javascript call EnterJavaScript()

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

" Vimdfiff
"au FilterWritePre * if &diff | syntax off | endif
"highlight DiffAdd cterm=none ctermfg=bg ctermbg=green gui=none guifg=bg guibg=Green
"highlight DiffDelete cterm=none ctermfg=bg ctermbg=Red gui=none guifg=bg guibg=Red
"highlight DiffChange cterm=none ctermfg=bg ctermbg=Yellow gui=none guifg=bg guibg=Yellow
"highlight DiffText cterm=none ctermfg=bg ctermbg=Magenta gui=none guifg=bg guibg=Magenta

highlight DiffAdd term=reverse cterm=bold ctermbg=green ctermfg=white
highlight DiffChange term=reverse cterm=bold ctermbg=cyan ctermfg=black
highlight DiffText term=reverse cterm=bold ctermbg=gray ctermfg=black
highlight DiffDelete term=reverse cterm=bold ctermbg=red ctermfg=black


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
"if has("unix")
"    autocmd BufWritePost *
"                \   if getline(1) =~ "^#!"            |
"                \       if getline(1) =~ "/bin/"      |
"                \           silent !chmod +x <afile>; |
"                \       endif                         |
"                \   endif
"endif
