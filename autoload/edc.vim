" Settings:
"   g:edc_echo    Echo the parsed files (default: 0).
"   g:edc_silent  Don't show parse errors (default: 0).
"
" Variables:
"   b:edc_conf    Parsed file(s).
"   b:edc_errors  List of errors (if any, may be unset).
scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

fun! edc#init() abort
	let l:conf = s:load_files()

	let b:edc_conf = l:conf

	if get(g:, 'edc_echo', 0)
		echom printf('%s', l:conf)
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


" *	            Matches any string of characters, except path separators (/)
" **	        Matches any string of characters
" ?	            Matches any single character
" [name]	    Matches any single character in name
" [!name]	    Matches any single character not in name
" {s1,s2,s3}	Matches any of the strings given (separated by commas)
" {num1..num2}	Matches any integer numbers between num1 and num2, where num1
"               and num2 can be either positive or negative
" 
" Special characters can be escaped with a backslash so they won't be
" interpreted as wildcard patterns.
fun! s:match(pat) abort
endfun

fun! s:err(msg, ...) abort
	if !exists('b:edc_errors')
		let b:edc_errors = []
	endif

	let l:err = printf(a:msg, a:000)
	call append(b:edc_errors, l:err)

	if get(g:, 'edc_silent', 0)
		return
	endif
	echohl ErrorMsg
	echom 'edc.vim: ' . l:err
	echohl None
endfun


let &cpo = s:save_cpo
unlet s:save_cpo
