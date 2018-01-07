if ROOTDIR == nil then
	ROOTDIR = tup.getcwd()
end

tup.creategitignore()

function quote(str)
	-- this quotes a string in a manner safe for shell (well, bash) usage via tup
	-- basically, this adds single quotes while escaping previously existing ones and doubles up on percentage signs
	-- TODO: find a way to deal with the $() and @() tup syntax
	-- TODO: fix tup, so that it really does not do substitutions when using definerule
	return "'"..(str:gsub("'", "'\\''"):gsub("%%", "%%%%")).."'"
end

function concat(options)
	assert(type(options[1]) == "table")
	assert(type(options[2]) == "string")
	local command = "^o Combining files into %o^ cat -- "
	for index,value in ipairs(options[1]) do
		command = command..quote(value).." "
	end
	command = command..">"..quote(options[2])
	tup.definerule{
		inputs = options[1],
		command = command,
		outputs = {options[2]},
	}
end

function doc_outdir(output)
	if ROOTDIR == "." then
		return "build/doc/"..output
	else
		return ROOTDIR.."/build/doc/"..tup.getrelativedir(ROOTDIR).."/"..output
	end
end

function latexmk(options)
	local texfile = options[1]
	local output
	if options[2] == nil then output = tup.getdirectory()..".pdf" else output = options[2] end
	local source_epoch
	if options.source_epoch == nil then source_epoch = 0 else source_epoch = options.source_epoch end
	assert(texfile ~= nil)
	assert(output ~= nil)
	local outdir = doc_outdir(output)
	local command = "env SOURCE_DATE_EPOCH="..quote(tostring(source_epoch)).." USER=author"
	if options.latex == nil or options.latex == "xelatex" then
		command = command.." latexmk -pdf -xelatex -output-directory="..quote(outdir).." -jobname=result "..quote(texfile)
	elseif options.latex == "pdflatex" then
		command = command.." latexmk -pdf -output-directory="..quote(outdir).." -jobname=result "..quote(texfile)
	else
		assert(false, command.latex.." is an unknown latex option")
	end
	-- make crossrefs usable
	command = command.." -e "..quote("$bibtex = 'bibtex --min-crossrefs=1000 %O %B';")
	local foo = quote(outdir.."/foo")
	local bonus = {
		outdir.."/result.aux",
		outdir.."/result.bbl",
		outdir.."/result.blg",
		outdir.."/result.fdb_latexmk",
		outdir.."/result.fls",
		outdir.."/result.log",
		outdir.."/result.nav",
		outdir.."/result.out",
		outdir.."/result.snm",
		outdir.."/result.toc",
		outdir.."/result.upa",
		outdir.."/result.upb",
		outdir.."/result.vrb",
		outdir.."/result.xdv",
	}
	local result = outdir..'/result.pdf'
	local result_bonus = {result}
	for key,file in pairs(bonus) do
		command += "&& touch "..foo
		command += "&& mv -n "..foo.." "..quote(file)
		table.insert(result_bonus, file)
	end
	command += "&& rm -f "..foo
	local input = {texfile}
	if type(options.extra_inputs) == "string" then
		table.insert(input, options.extra_inputs)
	elseif type(options.extra_inputs) == "table" then
		tup.append_table(input, options.extra_inputs)
	end
	tup.definerule{
		inputs = input,
		command = tostring(command),
		outputs = result_bonus
	}
	local outputs = {output}
	if options.group ~= nil then
		assert(type(options.group) == "string")
    table.insert(outputs, options.group)
	end
	tup.definerule{
		inputs = {result},
		command = "^o Copying out %o^ cp "..quote(result).." "..quote(output),
		outputs = outputs
	}
end

function pdfcrop(options)
	local input = options[1]
	local ext = tup.ext(input)
	assert(ext == "pdf")
	local output
	if options[2] == nil then output = input:sub(0,-5).."_cropped.pdf" else output = options[2] end
	local outdir = doc_outdir(output)
	local result = outdir..'/'..output
	tup.definerule{
		inputs = {input},
		command = "^o Cropping %f^ pdfcrop "..quote(input).." "..quote(result),
		outputs = {result}
	}
	local outputs = {output}
	if options.group ~= nil then
		assert(type(options.group) == "string")
    table.insert(outputs, options.group)
	end
	tup.definerule{
		inputs = {result},
		command = "^o Copying out %o^ cp "..quote(result).." "..quote(output),
		outputs = {output}
	}
end

function pdfcompress(options)
	local input = options[1]
	local ext = tup.ext(input)
	assert(ext == "pdf")
	local output
	if options[2] == nil then output = input:sub(0,-5).."_cropped.pdf" else output = options[2] end
	local outdir = doc_outdir(output)
	local result = outdir..'/'..output
	tup.definerule{
		inputs = {input},
		command = "^o Compressing %f^ gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dDetectDuplicateImages -dCompressFonts=true -sOutputFile="..quote(result).." "..quote(input),
		outputs = {result}
	}
	local outputs = {output}
	if options.group ~= nil then
		assert(type(options.group) == "string")
    table.insert(outputs, options.group)
	end
	tup.definerule{
		inputs = {result},
		command = "^o Copying out %o^ cp "..quote(result).." "..quote(output),
		outputs = {output}
	}
end

function pdfgreyscale(options)
	local input = options[1]
	local ext = tup.ext(input)
	assert(ext == "pdf")
	local output
	if options[2] == nil then output = input:sub(0,-5).."_grey.pdf" else output = options[2] end
	local outdir = doc_outdir(output)
	local result = outdir..'/'..output
	tup.definerule{
		inputs = {input},
		command = "^o Creating greyscale version of %f^ gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dDetectDuplicateImages -dCompressFonts=true -sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray -sOutputFile="..quote(result).." "..quote(input),
		outputs = {result}
	}
	local outputs = {output}
	if options.group ~= nil then
		assert(type(options.group) == "string")
    table.insert(outputs, options.group)
	end
	tup.definerule{
		inputs = {result},
		command = "^o Copying out %o^ cp "..quote(result).." "..quote(output),
		outputs = {output},
	}
end

function pdf2jpg(options)
	local input = options[1]
	local ext = tup.ext(input)
	assert(ext == "pdf")
	local output
	if options[2] == nil then output = input:sub(0,-5)..".jpg" else output = options[2] end
	local outdir = doc_outdir(output)
	local result = outdir..'/'..output
	tup.definerule{
		inputs = {input},
		command = "^o Creating jpg version of %f^ convert -density 600 -colorspace rgb "..quote(input).." "..quote(result),
		outputs = {result}
	}
	local outputs = {output}
	if options.group ~= nil then
		assert(type(options.group) == "string")
    table.insert(outputs, options.group)
	end
	tup.definerule{
		inputs = {result},
		command = "^o Copying out %o^ cp "..quote(result).." "..quote(output),
		outputs = {output}
	}
end
