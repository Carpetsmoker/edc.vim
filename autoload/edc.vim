" Settings:
"   g:edc_echo    Echo diagnositc informatin (default: 0).
"   g:edc_silent  Don't show parse errors (default: 0).
"
" Variables:
"   b:edc_conf    Parsed file(s).
"   b:edc_errors  List of errors (if any, may be unset).
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" TODO: make settings available in simple b: dict {"rule": "val", ...}
fun! edc#init() abort
	let l:conf = s:load_files()
	let l:conf = filter(l:conf, {k, v -> l:k isnot '' && edc#match(l:k)})
	let b:edc_conf = l:conf
	if get(g:, 'edc_echo', 0)
		echom printf('edc.vim: config: %s', l:conf)
	endif

	for l:rules in values(l:conf)
		for [l:rule, l:val] in items(l:rules)
			call s:apply(l:rule, l:val)
		endfor
	endfor
endfun

" https://github.com/editorconfig/editorconfig/wiki/EditorConfig-Properties
"
" TODO: boolify some values
" TODO: more useful error reporting.
" TODO: support some domain-specific properties
fun! s:apply(rule, val) abort
	if get(g:, 'edc_echo', 0)
		echom printf('edc.vim: apply %s -> %s', a:rule, a:val)
	endif

	if a:rule is# 'indent_style'
		let &l:expandtab = {'tab': 0, 'space': 1}[a:val]

	elseif a:rule is# 'indent_size'
		let &l:shiftwidth = a:val is# 'tab' ? 0 : a:val

	elseif a:rule is# 'tab_width'
		let &l:tabstop = a:val

	elseif a:rule is# 'end_of_line'
		let &l:fileformat = {'lf': 'unix' 'cr': 'mac' 'crlf': 'dos'}[a:val]

	elseif a:rule is# 'charset'
		" TODO: set 'bomb'? Maybe parse value smarter?
		let &l:fileencoding = a:val

	elseif a:rule is# 'insert_final_newline'
		let &l:endofline = a:val
		let &l:fixendofline = 0

	elseif a:rule is# 'trim_trailing_whitespace'
		fun! s:trim_trailing() abort
			let l:save = winsaveview()
			keeppatterns %s/\s\+$//e
			call winrestview(l:save)
		endfun
		autocmd plugin-edc BufWritePre <buffer> call s:trim_trailing()

	elseif a:rule is# 'max_line_length'
		let &l:textwidth = a:val is# 'off' ? 0 : a:val

	else
		call s:err('unknown rule: %s', a:rule)
	endif
endfun

" Load all .editorconfig files until there's one with root = true.
fun! s:load_files() abort
	let l:ret = {}

	for l:path in findfile('.editorconfig', '.;', -1)
		call extend(l:ret, s:parse(l:path), 'keep')
		if get(l:ret[''], 'root', 0)
			break
		endif
	endfor

	return l:ret
endfun

" Parse a single .editorconfig file.
"
" TODO: this loses the ordering of the matches, but spec says:
"    files are read top to bottom and the most recent rules found take precedence.
"    Properties from matching EditorConfig sections are applied in the order they
"    were read, so properties in closer files take precedence.
"
" {
"    "*": {
"     "root": 1,
"    },
"    "*.vim": {
"		
"    },
"    "*.{txt,csv}": {
"    },
" }
"
" https://editorconfig.org/#file-format-details
" https://docs.python.org/2/library/configparser.html
fun! s:parse(path) abort
	let l:key = ''
	let l:ret = {'': {}}
	let l:section = ''

	let l:lines = readfile(a:path)
	for l:i in range(len(l:lines))
		let l:line = trim(l:lines[l:i])

		" Remove everything after comment character. Only ; can be used for
		" inline comments and must be preceded by whitespace.
		let l:c = match(l:line, '\s;')
		if l:c > -1
			let l:line = l:line[:l:c - 1]
		endif

		" Skip blank lines and comments.
		if l:line is# '' || l:line[0] is# '#'
			continue
		end

		" Section.
		if l:line[0] is# '['
			let l:section = trim(trim(l:line, '[]'))
			let l:ret[l:section] = {}
			continue
		endif

		" Line continuation.
		if match(l:line, '^\s') > -1
			/let l:ret[l:section][l:key] .= trim(l:line)
			continue
		endif

		" Split key and value.
		" TODO: look at ConfigParser source.
		if stridx(l:line, '=') > -1
			let l:chr = '='
		elseif stridx(l:line, ':') > -1
			let l:chr = ':'
		else
			call s:err('%s: could not parse line %d', l:path, l:i)
			continue
		endif

		" Properties and values are case-insensitive.
		let l:split = split(tolower(l:line), l:chr)

		" TODO: For any property, a value of "unset" is to remove the effect of
		" that property, even if it has been set before.

		let l:key = trim(l:split[0])
		let l:ret[l:section][l:key] = trim(join(l:split[1:], l:chr))
	endfor

	return l:ret
endfun

" Automatically supported:
" [name]        Matches any single character in name.
"
" TODO:
" {num1..num2}  Matches any integer numbers between num1 and num2, where num1
"               and num2 can be either positive or negative.
" 
" Note: glob2regpat() is close, but treats * and ** the same, and doesn't
" support {num1..num2}.
let s:glob_to_reg = [
		"\ [!name] Matches any single character not in name.
		\ ['\[!',       '[^'],
		"\ {s1,s2,s3} Matches any of the strings given (separated by commas).
		\ ['{[^}]*}',   '\="\\%(" . substitute(submatch(0)[1:-2], ",", "\\\\|", "g") . "\\)"'],
		"\ ** Matches any string of characters.
		\ ['\*\*',      '.\\{}'],
		"\ * Matches any string of characters, except path separators (/).
		\ ['\*',        '[^/]\\{}'],
		"\ ? Matches any single character.
		\ ['?',         '.'],
\ ]

" Report if the current filename matches the given pattern.
fun! edc#match(pat) abort
	" Quick match.
	if a:pat is# '*' || a:pat is# '**'
		return 1
	endif

	" TODO: escape other regexp chars?
	let l:pat = escape(a:pat, '.')

	for [l:f, l:r] in s:glob_to_reg
		" Special characters can be escaped with a backslash so they won't be
		" interpreted as wildcard patterns.
		let l:pat = substitute(l:pat, '\\\@<!' . l:f, l:r, 'g')
	endfor

	let b:last_pat = l:pat

	" TODO: vim-editorconfig prepends with \<; not sure why? Probably not for
	" the craic?
	" TODO: adding the $ anchor intuitively makes sense, but is not specified as
	" far as I can see.
	return match(expand('%:p'), l:pat . '$') > -1
endfun

fun! s:err(msg, ...) abort
	if !exists('b:edc_errors')
		let b:edc_errors = []
	endif

	let l:err = call('printf', [a:msg] + a:000)
	call add(b:edc_errors, l:err)

	if get(g:, 'edc_silent', 0)
		return
	endif
	echohl ErrorMsg
	echom 'edc.vim: ' . l:err
	echohl None
endfun


let &cpo = s:save_cpo
unlet s:save_cpo
