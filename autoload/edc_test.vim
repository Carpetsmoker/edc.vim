fun! Test_parse() abort
	let l:tests = [
			\ [
				\ 'just root',
				\ ['root = true'],
				\ {'': {'root': 'true'}},
			\ ],
			\ [
				\ 'empty section',
				\ ['root = true', '[*.vim]'],
				\ {'': {'root': 'true'}, '*.vim': {}},
			\ ],
			\ [
				\ '= value',
				\ ['[*.vim]', 'setting = xx'],
				\ {'': {}, '*.vim': {'setting': 'xx'}},
			\ ],
			\ [
				\ ': value',
				\ ['[*.vim]', 'setting : xx'],
				\ {'': {}, '*.vim': {'setting': 'xx'}},
			\ ],
			\ [
				\ 'line comment',
				\ ['#foo', '[*.vim]', 'setting : xx', '# foo'],
				\ {'': {}, '*.vim': {'setting': 'xx'}},
			\ ],
			\ [
				\ 'inline ; comment',
				\ ['[*.vim] ; comment', 'setting : xx ; comment'],
				\ {'': {}, '*.vim': {'setting': 'xx'}},
			\ ],
			\ [
				\ 'overwrite',
				\ ['[*.vim]', 'setting = xx', 'setting = later'],
				\ {'': {}, '*.vim': {'setting': 'later'}},
			\ ],
			\ [
				\ 'case insensitive',
				\ ['[*.vim]', 'setting = xx', 'SETTING: LATER   '],
				\ {'': {}, '*.vim': {'setting': 'later'}},
			\ ],
	\ ]

	for [l:name, l:test, l:want] in l:tests
		new
		call setline(1, l:test)
		silent wq! .editorconfig

		e test
		if b:edc_conf != l:want
			call Errorf("%s failed\nout:  %s\nwant: %s",
						\ l:name, b:edc_conf, l:want)
		endif
	endfor
endfun
