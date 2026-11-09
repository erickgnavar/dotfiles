set nocompatible

" --- vim-plug bootstrap -------------------------------------------------
" Downloads plug.vim to ~/.vim/autoload/ on first run so plug#begin is
" available immediately, then runs :PlugInstall to fetch the plugins.
let s:plug_install = empty(glob('~/.vim/autoload/plug.vim'))
if s:plug_install
    echo "Installing vim-plug..."
    silent !mkdir -p ~/.vim/autoload
    silent !curl -fLo ~/.vim/autoload/plug.vim
        \ https://raw.githubusercontent.com/junegunn/vim-plug/0.15.0/plug.vim
endif
call plug#begin('~/.vim/plugged')

" Plugins
Plug 'tomtom/tcomment_vim', { 'commit': '48ab639a461d9b8344f7fee06cb69b4374863b13' }
" Zen coding
Plug 'mattn/emmet-vim', { 'commit': '92ef2f74f4093edc99db5e9e4cf7e40116a85bd6' }
" Airline
Plug 'vim-airline/vim-airline', { 'commit': '8dc1bd0a116de527f6bc58c1d04386ba357c624f' }
Plug 'vim-airline/vim-airline-themes', { 'commit': '77aab8c6cf7179ddb8a05741da7e358a86b2c3ab' }
Plug 'tpope/vim-surround', { 'commit': '3d188ed2113431cf8dac77be61b842acb64433d9' }
Plug 'Townk/vim-autoclose', { 'commit': 'a9a3b7384657bc1f60a963fd6c08c63fc48d61c3' }
Plug 'lilydjwg/colorizer', { 'commit': '72790a003d5a706c287486a1a81e3a6b32158b54' }
Plug 'editorconfig/editorconfig-vim', { 'commit': 'c0227885a06b155d5aa5465e08b9800e8c939f70' }
Plug 'sheerun/vim-polyglot', { 'commit': 'f061eddb7cdcc614c8406847b2bfb53099832a4e' }
Plug 'elzr/vim-json', { 'commit': '3727f089410e23ae113be6222e8a08dd2613ecf2' }
Plug 'mattn/webapi-vim', { 'commit': 'c7eec04aad31e1665164d8292d0ec8b5c3cc5a57' }
Plug 'mattn/gist-vim', { 'commit': 'fd55721a8f7c2a7c23d2e704405047e03d6f95f6' }
Plug 'tpope/vim-fugitive', { 'commit': '3b753cf8c6a4dcde6edee8827d464ba9b8c4a6f0' }
Plug 'airblade/vim-gitgutter', { 'commit': '90b75207bd9b55d8ac4af15f72b4e935462014d0' }
Plug 'henrik/vim-indexed-search', { 'commit': '763fdd0eb818ad441433aa04d00eabfda579476c' }
Plug 'airblade/vim-rooter', { 'commit': '51402fb77c4d6ae94994e37dc7ca13bec8f4afcc' }
Plug 'terryma/vim-expand-region', { 'commit': '966513543de0ddc2d673b5528a056269e7917276' }
Plug 'chriskempson/tomorrow-theme', {
    \ 'commit': 'ccf6666d888198d341b26b3a99d0bc96500ad503',
    \ 'rtp': 'vim',
    \ }
" Provides the fzf#run autoload glue used by fzf.vim; the binary comes from the system.
Plug 'junegunn/fzf', { 'commit': 'c7bf2b8eea25952dd257a466c0afa72faae206fb' }
Plug 'junegunn/fzf.vim', { 'commit': '023de3c0e158ff9c2b0992175af10be97c2f2158' }
Plug 'andymass/vim-matchup', { 'commit': '0106b1afd4a2f7e1098037b5ceb161bab7471088' }

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
