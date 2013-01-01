if exists('g:loaded_rsense')
  finish
endif
let g:loaded_rsense = 1

" initialize"{{{
if !exists('g:rsense_home')
  let g:rsense_home = expand("~/src/rsense")
endif

let s:rsense_completion_kind_dictionary = {'CLASS': 'C', 'MODULE': 'M', 'CONSTANT': 'c', 'METHOD': 'm'}

if !exists('g:rsense_use_omnifunc')
  let g:rsense_use_omnifunc = 0
endif

if !exists('g:rsense_match_func')
  let g:rsense_match_func = '[^. *\t]\.\w*\|\h\w*::'
endif

let s:rsense_dir_name = "rsense-0.3"

" Check vimproc.
let s:is_vimproc = exists('*vimproc#system')
"}}}

function! s:system(str, ...) "{{{
  return s:is_vimproc ?
        \ (a:0 == 0 ? vimproc#system(a:str) : vimproc#system(a:str, join(a:000)))
        \: (a:0 == 0 ? system(a:str) : system(a:str, join(a:000)))
endfunction "}}}

function! s:rsense_program() "{{{
  let bundle_dir = neobundle#get_neobundle_dir()
  return bundle_dir . '/' . s:rsense_dir_name . '/bin/rsense'
endfunction "}}}

function! s:rsense_command(args) "{{{
  for i in range(0, len(a:args) - 1)
    let a:args[i] = shellescape(a:args[i])
  endfor
  return s:system(printf('ruby %s %s %s',
        \ shellescape(s:rsense_program()),
        \ join(a:args, ' '),
        \ shellescape('--detect-project=' . bufname('%'))))
endfunction"}}}

function! s:rsense_current_buffer_file() "{{{
  let buf = getline(1, '$')
  let file = tempname()
  call writefile(buf, file)
  return file
endfunction"}}}

function! s:rsense_current_buffer_fileOption() "{{{
  return '--file=' . s:rsense_current_buffer_file()
endfunction"}}}

function! s:rsense_current_location_option() "{{{
  return printf('--location=%s:%s', line('.'), col('.') - (mode() == 'n' ? 0 : 1))
endfunction"}}}

function! RSenseCompleteFunction(findstart, base) "{{{
  if a:findstart
    let cur_text = strpart(getline('.'), 0, col('.') - 1)
    return match(cur_text, '[^\.:]*$')
  else
    let result = split(s:rsense_command(['code-completion',
          \ s:rsense_current_buffer_fileOption(),
          \ s:rsense_current_location_option(),
          \ '--prefix=' . a:base]),
          \ "\n")
    let completions = []
    for item in result
      if item =~ '^completion: '
        let ary = split(item, ' ')
        let dict = { 'word': ary[1] }
        if len(ary) > 4
          let dict['menu'] = ary[3]
          let dict['kind'] = s:rsense_completion_kind_dictionary[ary[4]]
        endif

        if match( dict['word'], g:rsense_match_func ) != -1
          call add(completions, dict)
        endif
      endif
    endfor
    return completions
  endif
endfunction"}}}

function! RSenseTypeHelp() "{{{
  let result = split(s:rsense_command(['type-inference', s:rsense_current_buffer_fileOption(), s:rsense_current_location_option()]), "\n")
  let types = []
  for item in result
    if item =~ '^type: '
      call add(types, split(item, ' ')[1])
    endif
  endfor
  return len(types) == 0 ? 'No type information' : join(types, ' | ')
endfunction"}}}

function! RSenseJumpToDefinition() "{{{
  let tempfile = s:rsense_current_buffer_file()
  let result = split(s:rsense_command(['find-definition',
        \ '--file=' . tempfile,
        \ s:rsense_current_location_option()]),
        \ "\n")
  for item in result
    " TODO selection interface
    if item =~ '^location: '
      let ary = split(item, ' ')
      let file = join(ary[2:], ' ')
      let line = ary[1]
      " Unmap for tempfile
      if file == tempfile
        let file = bufname('%')
      endif
      execute printf("edit +%s %s", line, file)
      return
    endif
  endfor
  echo 'No definition found'
endfunction"}}}

function! RSenseWhereIs() "{{{
  let result = split(s:rsense_command(['where', s:rsense_current_buffer_fileOption(), '--line=' . line('.')]), "\n")
  for item in result
    if item =~ '^name: '
      echo split(item, ' ')[1]
      return
    endif
  endfor
  echo 'Unknown'
endfunction"}}}

function! RSenseVersion() "{{{
  return s:rsense_command(['version'])
endfunction"}}}

function! RSenseServiceStart() "{{{
  return s:rsense_command(['service', 'start'])
endfunction"}}}

function! RSenseServiceStop() "{{{
  return s:rsense_command(['service', 'stop'])
endfunction"}}}

function! RSenseServiceStatus() "{{{
  return s:rsense_command(['service', 'status'])
endfunction"}}}

function! RSenseOpenProject(directory) "{{{
  call s:rsense_command(['open-project', expand(a:directory)])
endfunction"}}}

function! RSenseCloseProject(project) "{{{
  call s:rsense_command(['close-project', expand(a:project)])
endfunction"}}}

function! RSenseClear() "{{{
  call s:rsense_command(['clear'])
endfunction"}}}

function! RSenseExit() "{{{
  call s:rsense_command(['exit'])
endfunction"}}}

" define commands"{{{
command! -narg=0 RSenseTypeHelp         echo RSenseTypeHelp()
command! -narg=0 RSenseJumpToDefinition call RSenseJumpToDefinition()
command! -narg=0 RSenseWhereIs          call RSenseWhereIs()
command! -narg=0 RSenseVersion          echo RSenseVersion()
command! -narg=0 RSenseServiceStart     echo RSenseServiceStart()
command! -narg=0 RSenseServiceStop      echo RSenseServiceStop()
command! -narg=0 RSenseServiceStatus    echo RSenseServiceStatus()
command! -narg=0 RSenseClear            call RSenseClear()
command! -narg=0 RSenseExit             call RSenseExit()
command! -narg=1 RSenseOpenProject      call RSenseOpenProject('<args>')
command! -narg=1 RSenseCloseProject     call RSenseCloseProject('<args>')
"}}}

function! SetupRSense()
  if g:rsense_use_omnifunc
    setlocal omnifunc=RSenseCompleteFunction
  else
    setlocal completefunc=RSenseCompleteFunction
  endif
endfunction

autocmd FileType ruby call SetupRSense()
