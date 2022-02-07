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
Plugin 'tomtom/tcomment_vim'
" Zen coding
Plugin 'mattn/emmet-vim'
" Airline
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'tpope/vim-surround'
Plugin 'Townk/vim-autoclose' " Allow show diff sign of opened files
Plugin 'lilydjwg/colorizer'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'sheerun/vim-polyglot'  " Plugins for most of the programming languages
Plugin 'elzr/vim-json'
Plugin 'mattn/webapi-vim' "gist-vim requirement
Plugin 'mattn/gist-vim'
Plugin 'tpope/vim-fugitive'
Plugin 'airblade/vim-gitgutter'
Plugin 'henrik/vim-indexed-search'
Plugin 'airblade/vim-rooter'
Plugin 'terryma/vim-expand-region'
Plugin 'dracula/vim'
Plugin 'junegunn/fzf'
Plugin 'junegunn/fzf.vim'
Plugin 'andymass/vim-matchup'

let g:loaded_matchit = 1

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

" avoid to show an error with long file paths
set shortmess=F

set number "show line numbers
set showcmd "show last command
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

" Setup clipboard
set clipboard=unnamed

" Setup leader functions
nmap <Leader>a :Ag<space>
nmap <Leader>b :Buffers<ENTER>
nmap <Leader>c :ClearCtrlPCache<ENTER>
nmap <leader>e :call MyFindFiles()<ENTER>
nmap <Leader>g :Git<ENTER>
nmap <Leader>k :bdelete<space>
nmap <Leader>n :enew<ENTER>

function MyFindFiles()
  if len(system('git rev-parse'))
    :Files
  else
    :GFiles --exclude-standard --others --cached
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
