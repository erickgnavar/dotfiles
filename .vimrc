set nocompatible

" --- vim-plug bootstrap -------------------------------------------------
" Downloads plug.vim to ~/.vim/autoload/ on first run so plug#begin is
" available immediately, then runs :PlugInstall to fetch the plugins.
let s:plug_install = empty(glob('~/.vim/autoload/plug.vim'))
if s:plug_install
    echo "Installing vim-plug..."
    silent !mkdir -p ~/.vim/autoload
    silent !curl -fLo ~/.vim/autoload/plug.vim
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif
call plug#begin('~/.vim/plugged')

" Plugins
Plug 'tomtom/tcomment_vim'
" Zen coding
Plug 'mattn/emmet-vim'
" Airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tpope/vim-surround'
Plug 'Townk/vim-autoclose' " Allow show diff sign of opened files
Plug 'lilydjwg/colorizer'
Plug 'editorconfig/editorconfig-vim'
Plug 'sheerun/vim-polyglot'  " Plugins for most of the programming languages
Plug 'elzr/vim-json'
Plug 'mattn/webapi-vim' "gist-vim requirement
Plug 'mattn/gist-vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'henrik/vim-indexed-search'
Plug 'airblade/vim-rooter'
Plug 'terryma/vim-expand-region'
Plug 'chriskempson/tomorrow-theme', { 'rtp': 'vim' }
" Provides the fzf#run autoload glue used by fzf.vim; the binary comes from the system.
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'andymass/vim-matchup'

call plug#end()

let g:loaded_matchit = 1

if s:plug_install
    echo "Installing plugins, please ignore key map error messages"
    echo ""
    :PlugInstall
endif

" ============================================================================
" Vim settings and mappings
" You can edit them as you wish

" allow plugins by file type (required for plugins!)
filetype plugin on
filetype indent on

" tabs and spaces handling
set expandtab
set tabstop=4
set softtabstop=4
set shiftwidth=4

set ls=2 "always show status bar

set incsearch "incremental search
set hlsearch "highlighted search results

syntax enable "enable syntax highlight
set path+=**

" avoid to show an error with long file paths
set shortmess=F

set number "show line numbers
set showcmd "show last command
set wildmenu "visual autocomplete for command menu
set showmatch "highlight match [{}]
set encoding=utf-8
nnoremap <space> za

" Gist commands
let g:gist_clip_command = 'pbcopy'
let g:gist_detect_filetype = 1

set completeopt-=preview

" save as sudo
ca w!! w !sudo tee "%"

" colors
if has('gui_running')
    set guifont=JetBrainsMono\ Nerd\ Font:h12
endif

silent! colorscheme Tomorrow-Night-Bright

set scrolloff=3 " when scrolling, keep cursor 3 lines away from screen border

" better backup, swap and undos storage
set directory=~/.vim/dirs/tmp     " directory to place swap files in
set backup                        " make backup files
set backupdir=~/.vim/dirs/backups " where to put backup files
set undofile                      " persistent undos - undo after you re-open the file
set undodir=~/.vim/dirs/undos
set viminfo+=n~/.vim/dirs/viminfo

" create needed directories if they don't exist
if !isdirectory(&backupdir)
    call mkdir(&backupdir, "p")
endif
if !isdirectory(&directory)
    call mkdir(&directory, "p")
endif
if !isdirectory(&undodir)
    call mkdir(&undodir, "p")
endif

" Setup clipboard
set clipboard=unnamed

" Setup leader functions
nmap <Leader>a :Rg<space>
nmap <Leader>b :Buffers<ENTER>
nmap <Leader>c :ClearCtrlPCache<ENTER>
nmap <leader>e :call MyFindFiles()<ENTER>
nmap <Leader>g :Git<ENTER>
nmap <Leader>k :bdelete<space>
nmap <Leader>n :enew<ENTER>
nmap <Leader>q :BLines<ENTER>

function MyFindFiles()
  if system('git rev-parse --is-inside-work-tree 2>/dev/null') =~ 'true'
    :GFiles --exclude-standard --others --cached
  else
    :Files
  endif
endfunction

" " Autoclose ------------------------------
" " Fix to let ESC work as espected with Autoclose plugin
let g:AutoClosePumvisible = {"ENTER": "\<C-Y>", "ESC": "\<ESC>"}

set backspace=2

let g:airline_powerline_fonts = 0
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#whitespace#enabled = 0

set lazyredraw
set ttyfast

" GitGutter config
set updatetime=100

" Navigate through hunks
nmap <c-n> <Nop>
nmap <c-p> <Nop>
nmap <c-n> :GitGutterNextHunk<ENTER>
nmap <c-p> :GitGutterPrevHunk<ENTER>

" automatically rebalance windows on vim resize
autocmd VimResized * :wincmd = "
