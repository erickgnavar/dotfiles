set nocompatible

let iCanHazVundle=1
let vundle_readme=expand('~/.vim/bundle/vundle/README.md')

if !filereadable(vundle_readme)
    echo "Installing Vundle..."
    echo ""
    silent !mkdir -p ~/.vim/bundle
    silent !git clone https://github.com/gmarik/vundle ~/.vim/bundle/vundle
    let iCanHazVundle=0
endif

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" Plugins
Plugin 'gmarik/vundle'
Plugin 'scrooloose/nerdtree'
Plugin 'tComment'
Plugin 'kien/ctrlp.vim'
" Zen coding
Plugin 'mattn/emmet-vim'
" Airline
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'tpope/vim-surround'
Plugin 'Townk/vim-autoclose' " Allow show diff sign of opened files
Plugin 'lilydjwg/colorizer'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'elixir-lang/vim-elixir'
Plugin 'bash-support.vim'
Plugin 'elzr/vim-json'
Plugin 'mattn/webapi-vim' "gist-vim requirement
Plugin 'mattn/gist-vim'
Plugin 'docker/docker' , {'rtp': '/contrib/syntax/vim/'}
Plugin 'rking/ag.vim'
Plugin 'airblade/vim-gitgutter'
Plugin 'morhetz/gruvbox'
Plugin 'pangloss/vim-javascript'
Plugin 'IndexedSearch'
" XML/HTML tags navigation
Plugin 'matchit.zip'
Plugin 'terryma/vim-expand-region'
Plugin 'rhysd/vim-color-spring-night'
Plugin 'dracula/vim'

if iCanHazVundle == 0
    echo "Installing Bundles, please ignore key map error messages"
    echo ""
    :BundleInstall
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

set number "show line numbers
set relativenumber
set showcmd "show last command
set cursorline "highlight cursor line
set wildmenu "visual autocomplete for command menu
set showmatch "highlight match [{}]
set foldenable "enable folding
set foldmethod=indent
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
    set guifont=Monaco:h12
endif

" colorscheme spring-night
color dracula

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

" NERDTree -----------------------------
map <F3> :NERDTreeToggle<CR>
let NERDTreeIgnore = ['\.pyc$', '\.pyo$', '\.beam$', '\.mo$', '/.class$']
let g:vim_debug_disable_mappings = 1

" CtrlP ------------------------------
" don't change working directory
let g:ctrlp_working_path_mode = 0
" ignore these files and folders on file finder
let g:ctrlp_custom_ignore = {
  \ 'dir':  '\v[\/](\.git|\.hg|\.svn|\.idea|node_modules|bower_components)$',
  \ 'file': '\.pyc$\|\.pyo|\.beam$',
  \ }

" Setup leader functions
nmap <Leader>a :Ag<space>
nmap <Leader>b :buffer<space>
nmap <Leader>c :ClearCtrlPCache<ENTER>
nmap <Leader>e :CtrlP<ENTER>
nmap <Leader>k :bdelete<space>
nmap <Leader>n :enew<ENTER>

" " Autoclose ------------------------------
" " Fix to let ESC work as espected with Autoclose plugin
let g:AutoClosePumvisible = {"ENTER": "\<C-Y>", "ESC": "\<ESC>"}

set splitbelow
set splitright

set backspace=2

let g:airline_powerline_fonts = 0
let g:airline_theme = 'spring_night'
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#whitespace#enabled = 0

set lazyredraw
set ttyfast
