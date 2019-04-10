fun! Test_parse() abort
	let l:tests = [
			\ [
				\ 'just root',
				\ ['root = true'],
				\ [[]],
			\ ],
			\ [
				\ 'empty section',
				\ ['root = true', '[*.vim]'],
				\ [['*.vim', {}]],
			\ ],
			\ [
				\ '= value',
				\ ['[*.vim]', 'setting = xx'],
				\ [['*.vim', {'setting': 'xx'}]],
			\ ],
			\ [
				\ ': value',
				\ ['[*.vim]', 'setting : xx'],
				\ [['*.vim', {'setting': 'xx'}]],
			\ ],
			\ [
				\ 'line comment',
				\ ['#foo', '[*.vim]', 'setting : xx', '# foo'],
				\ [['*.vim', {'setting': 'xx'}]],
			\ ],
			\ [
				\ 'inline ; comment',
				\ ['[*.vim] ; comment', 'setting : xx ; comment'],
				\ [['*.vim', {'setting': 'xx'}]],
			\ ],
			\ [
				\ 'overwrite',
				\ ['[*.vim]', 'setting = xx', 'setting = later'],
				\ [['*.vim', {'setting': 'later'}]],
			\ ],
			\ [
				\ 'case insensitive',
				\ ['[*.vim]', 'setting = xx', 'SETTING: LATER   '],
				\ [['*.vim', {'setting': 'later'}]],
			\ ],
	\ ]

	for [l:name, l:test, l:want] in l:tests
		new
		call setline(1, l:test)
		silent wq! .editorconfig

		new
		let l:conf = edc#load_files()
		if l:conf != l:want
			call Errorf("%s failed\nout:  %s\nwant: %s",
						\ l:name, l:conf, l:want)
		endif
	endfor
endfun

fun! Test_match() abort
	let l:tests = [
			"\ *
			\ ['a.vim', '*', 1],
			\ ['a.vim', '*.vim', 1],
			\ ['foo/a.vim', 'bar/*.vim', 0],
			\ ['foo/a.vim', 'foo/*.vim', 1],
			\ ['foo/bar/a.vim', 'foo/*.vim', 0],
			\ ['a.vim', 'a*.vim', 1],
			"\ **
			\ ['a.vim', '**', 1],
			\ ['a.vim', '**.vim', 1],
			\ ['foo/a.vim', 'bar/**.vim', 0],
			\ ['foo/a.vim', 'foo/**.vim', 1],
			\ ['foo/bar/a.vim', 'foo/**.vim', 1],
			"\ ?
			\ ['a.vim', '?.vim', 1],
			\ ['a.vim', '??vim', 1],
			"\ [name]
			\ ['a.vim', '[abc].vim', 1],
			\ ['a.vim', '[def].vim', 0],
			"\ {s1,s2}
			\ ['a.vim', '{a,b}.vim', 1],
			\ ['a.vim', 'a.{vim,js}', 1],
			\ ['a.vim', '{c,d}.vim', 0],
			"\ Escape
			\ ['a.vim', 'a\*.vim', 0],
			\ ['foo/bar/a.vim', 'foo/\*\*.vim', 0],
		\]

	for [l:fname, l:pat, l:want] in l:tests
		exe ':e ' . l:fname
		let l:got = edc#match(l:pat)
		if l:got isnot l:want
			call Errorf("|%s| -> |%s| -> |%s|\nout:  %s\nwant: %s",
						\ l:pat, l:fname, b:last_pat, l:got, l:want)
		endif
	endfor
endfun
