function! repl#AsList(value)
    if type(value) == type([])
        return value
    else
        return [value]
    end
endfunction

function! repl#REPLGetName()"{{{
    if exists("b:REPL_OPEN_TERMINAL")
        return b:REPL_OPEN_TERMINAL
    elseif &buftype ==# 'terminal'
		return bufname('%')[1:]
	elseif has_key(g:repl_program, &filetype)
		return g:repl_program[&filetype]
	elseif has_key(g:repl_program, 'default')
		return g:repl_program['default']
	else
		return 'bash'
	endif
endfunction}}}"

function! repl#StringAfter(word, token)"{{{
    let l:loc = strridx(a:word, a:token)
    return a:word[(l:loc+1):]
endfunction}}}"

function! repl#REPLGetShortName()"{{{
    let l:name = repl#REPLGetName()
    return split(repl#StringAfter(l:name, '/'), ' ')[0]
endfunction}}}"

function! repl#REPLGetExitCommand()"{{{
	let l:name = repl#REPLGetName()
	if has_key(g:repl_exit_commands, l:name)
		return g:repl_exit_commands[l:name]
	elseif has_key(g:repl_exit_commands, 'default')
		return g:repl_exit_commands['default']
	else
		return 'exit'
	endif
endfunction}}}"

function! repl#REPLGoToWindowForBufferName(name)"{{{
	if bufwinnr(bufnr(a:name)) != -1
		exe bufwinnr(bufnr(a:name)) . 'wincmd w'
		return 1
	else
		return 0
	endif
endfunction"}}}

function! repl#REPLClose()"{{{

	if repl#REPLIsVisible()
		exe "call term_sendkeys('" . 'ZYTREPL' . ''', "\<C-W>\<C-C>")'
        exe "call term_wait('" . 'ZYTREPL' . ''', 50)'
		if repl#REPLIsVisible()
			exe "call term_sendkeys('" . 'ZYTREPL' . "', \"\\<Cr>\")"
            exe "call term_wait('" . 'ZYTREPL' . ''', 50)'
			exe "call term_sendkeys('" . 'ZYTREPL' . "', \"\\<Cr>\")"
            exe "call term_wait('" . 'ZYTREPL' . ''', 50)'
			exe "call term_sendkeys('" . 'ZYTREPL' . ''', "' . repl#REPLGetExitCommand() . '\<Cr>")'
            exe "call term_wait('" . 'ZYTREPL' . ''', 50)'
		endif
	endif

	exe bufwinnr(g:repl_target_n) . 'wincmd w'
    unlet b:REPL_OPEN_TERMINAL
endfunction"}}}

function! repl#REPLHide()
	if repl#REPLIsVisible()
		call repl#REPLGoToWindowForBufferName('ZYTREPL')
		hide!
	endif
endfunction

function! repl#REPLOpen(...)"{{{
    if a:0 == 0
        let b:REPL_OPEN_TERMINAL = repl#REPLGetName()
    else
        let b:REPL_OPEN_TERMINAL = join(a:000, ' ')
    endif
	exe 'autocmd bufenter * if (winnr("$") == 1 && (&buftype == ''terminal'') && bufexists(''ZYTREPL'')) | q! | endif'
	if g:repl_position == 0
		if exists('g:repl_height')
			exe 'bo term ++close ++rows=' . float2nr(g:repl_height) . ' ' . repl#REPLGetName()
		else
			exe 'bo term ++close ' . repl#REPLGetName()
		endif
	elseif g:repl_position == 1
		if exists('g:repl_height')
			exe 'to term ++close ++rows=' . float2nr(g:repl_height) . ' ' . repl#REPLGetName()
		else
			exe 'to term ++close ' . repl#REPLGetName()
		endif
	elseif g:repl_position == 2
		if exists('g:repl_width')
			exe 'vert term ++close ++cols=' . float2nr(g:repl_width) . ' ' . repl#REPLGetName()
		else
			exe 'vert term ++close ' . repl#REPLGetName()
		endif
	else
		if exists('g:repl_width')
			exe 'vert rightb term ++close ++cols=' . float2nr(g:repl_width) . ' ' . repl#REPLGetName()
		else
			exe 'vert rightb term ++close ' . repl#REPLGetName()
		endif
	endif
    exe 'file ZYTREPL'
endfunction"}}}


function! repl#REPLIsVisible()"{{{
	if bufwinnr(bufnr('ZYTREPL')) != -1
		return 1
	else
		return 0
	endif
endfunction"}}}

function! repl#REPLToggle(...)"{{{
	if repl#REPLIsVisible()
        let l:cursor_pos = getpos('.')
		call repl#REPLClose()
	else
        let l:cursor_pos = getpos('.')
		let g:repl_target_n = bufnr('')
		let g:repl_target_f = @%
        call call(function('repl#REPLOpen'), a:000)
	endif
	if g:repl_stayatrepl_when_open == 0
		exe bufwinnr(g:repl_target_n) . 'wincmd w'
        if exists('g:repl_predefine_' . repl#REPLGetShortName())
            let l:command_dict = eval('g:repl_predefine_' . repl#REPLGetShortName())
            for l:key in keys(l:command_dict)
                if search(l:key) != 0
                    call g:REPLSend(l:command_dict[l:key])
                endif
            endfor
        endif
        call cursor(l:cursor_pos[1], l:cursor_pos[2])
	endif
endfunction"}}}

function! repl#SendCurrentLine() abort
	if bufexists('ZYTREPL')
		exe "call term_sendkeys('" . 'ZYTREPL' . ''', getline(".") . "\<Cr>")'
		exe "call term_wait('" . 'ZYTREPL' . ''',  50)'
	endif
endfunction

function! repl#GetPythonClassCode(lines)
python3 << EOF
import vim

codes = vim.eval("a:lines")
firstline = ''
for t in codes:
    if len(t) != 0:
        firstline = t
        break
if firstline == '':
    newlines = []
else:
    indentfirst = len(firstline) - len(firstline.lstrip())
    i = 0
    newlines = []
    while i != len(codes):
        if codes[i].startswith("class "):
            endrow = i + 1
            peek = endrow
            newlines.append(codes[i])
            while(peek != len(codes)):
                if len(codes[peek].strip()) == 0:
                    peek += 1
                elif codes[peek][0] == ' ':
                    endrow = peek
                    newlines.append(codes[endrow][indentfirst:])
                    peek += 1
                else:
                    break
            newlines.append("")
            i = peek
        else:
            newlines.append(codes[i][indentfirst:])
            i += 1
EOF
return py3eval("newlines")
endfunction

function! repl#GetTerminalLine() abort
    let l:tl = term_getline('ZYTREPL', '.')
python3 << EOF
import vim
line = vim.eval('l:tl').rstrip()
EOF
return py3eval('line')
endfunction

function! repl#GetCurrentLineNumber() abort
    return term_getcursor('ZYTREPL')[0]
endfunction

function! repl#WaitHandler(channel) abort
    if len(s:tasks) == s:taskprocess
        return
    endif
    let l:tl = repl#GetTerminalLine()
    if index(s:waitforsymbols, l:tl) == -1
        call repl#WaitWH()
        return
    else
        call term_sendkeys('ZYTREPL', s:tasks[s:taskprocess] . "\<Cr>")
        let s:taskprocess = s:taskprocess + 1
        call repl#WaitWH()
        return
    endif
endfunction

function! repl#WaitWH() abort
    call job_start('sleep 0.03s', {'close_cb': 'repl#WaitHandler'})
endfunction

function! repl#Sends(tasks, symbols)
    let s:tasks = a:tasks
    let s:waitforsymbols = repl#AsList(a:symbols)
    let s:taskprocess = 0
    let s:currentlinenumber = -1
    call repl#WaitHandler(0)
endfunction

function! repl#WaitForSymbolsHandler(channel)
    let l:tl = repl#GetTerminalLine()
    if index(s:waitforsymbols, l:tl) == -1
        call repl#WAITFORSYMBOLS()
        return
    else
        return
    endif
endfunction

function! repl#WAITFORSYMBOLS() abort
    call job_start('sleep 0.03s', {'close_cb': 'repl#WaitForSymbolsHandler'})
endfunction

function! repl#WaitFor(symbols)
    let s:waitforsymbols = repl#AsList(a:symbols)
    call repl#WaitForSymbolsHandler(0)
endfunction

function! repl#SendChunkLines() range abort
	if bufexists('ZYTREPL')
		let l:firstline = a:firstline
		while(l:firstline <= a:lastline && strlen(getline(l:firstline)) == 0)
			let l:firstline = l:firstline + 1
		endwhile
        let l:sn = repl#REPLGetShortName()
        if l:sn =~ '.*python.*'
            call repl#Sends(add(getline(l:firstline, a:lastline), ''), ['>>>', '...', 'ipdb>', 'pdb>'])
        elseif has_key(g:repl_input_symbols, l:sn)
            call repl#Sends(add(getline(l:firstline, a:lastline), ''), g:repl_input_symbols[l:sn])
        else
            let l:fl = getline(l:firstline)
            let l:i = 0
            while(l:i < strlen(l:fl) && l:fl[l:i] ==# ' ')
                let l:i = l:i + 1
            endwhile
            for line in getline(l:firstline, a:lastline)
                let l:deletespaceline = line[l:i:]
                exe "call term_sendkeys('" . 'ZYTREPL' . ''', l:deletespaceline . "\<Cr>")'
                exe 'call term_wait("ZYTREPL", 50)'
            endfor
            exe "call term_sendkeys('" . 'ZYTREPL' . ''', "\<Cr>")'
        endif
	endif
endfunction

function! repl#REPLDebug() abort
    echo "REPL program"
    echo g:repl_program
    echo "REPL exit commands"
    echo g:repl_exit_commands
    echo "Current File Type:"
    echo &filetype
    echo "Current Type:"
    echo repl#REPLGetName()
    echo "Current Exit Commands"
    echo repl#REPLGetExitCommand()
endfunction