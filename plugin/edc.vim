if exists('g:loaded_edc')
	finish
endif
let g:loaded_edc = 1

if !has('autocmd') || !has('file_in_path')
	finish
endif

let s:save_cpo = &cpo
set cpo&vim

augroup plugin-edc
	au!
	au BufNewFile,BufReadPost * nested call edc#init()
augroup end

let &cpo = s:save_cpo
unlet s:save_cpo
