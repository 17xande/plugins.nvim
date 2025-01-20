local M = {}
M.setup = function()
	-- nothing
end

---@class present.Slides
---@field slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: The title of the slide
---@field body string: The body of the slide

--- Takes some lines and parses them.
---@param lines string[]: The lines in the buffer.
---@return present.Slides
local parse_slides = function(lines)
	local slides = { slides = {} }
	local current_slide = {
		title = "",
		body = {},
	}
	local separator = "^#"

	for _, line in ipairs(lines) do
		if line:find(separator) then
			if #current_slide.title > 0 then
				table.insert(slides.slides, current_slide)
			end

			current_slide = {
				title = line,
				body = {},
			}
		else
			table.insert(current_slide.body, line)
		end

		table.insert(current_slide, line)
	end

	table.insert(slides.slides, current_slide)

	return slides
end

local state = {
	floating = {
		buf = -1,
		win = -1,
	}
}

local function create_floating_window(opts)
	opts = opts or {}
	local width = opts.width or math.floor(vim.o.columns * 0.8)
	local height = opts.height or math.floor(vim.o.lines * 0.8)

	-- Calculate the position to center the window
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	-- Create a buffer
	local buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer.

	-- Define window configuration
	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	-- Create floating window
	local win = vim.api.nvim_open_win(buf, true, win_config)

	return { buf = buf, win = win }
end

M.start_presentation = function(opts)
	opts = opts or {}
	opts.bufnr = opts.bufnr or 0

	local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
	local parsed = parse_slides(lines)
	local float = create_floating_window()

	local set_slide_content = function(idx)
		vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[idx].body)
	end

	local current_slide = 1
	vim.keymap.set("n", "n", function()
		current_slide = math.min(current_slide + 1, #parsed.slides)
		set_slide_content(current_slide)
	end, { buffer = float.buf })

	vim.keymap.set("n", "p", function()
		current_slide = math.max(current_slide - 1, 1)
		set_slide_content(current_slide)
	end, { buffer = float.buf })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(float.win, true)
	end, { buffer = float.buf })

	local restore = {
		cmdheight = {
			original = vim.o.cmdheight,
			present = 0,
		}
	}

	-- Set the options we want during presentation.
	for option, config in pairs(restore) do
		vim.opt[option] = config.present
	end

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = float.buf,
		callback = function()
			-- Reset the options when we leave the buffer.
			for option, config in pairs(restore) do
				vim.opt[option] = config.original
			end
		end
	})

	set_slide_content(current_slide)
end

-- M.start_presentation({ bufnr = 4 })

-- vim.print(parse_slides({
-- 	"# Hello",
-- 	"this is something else",
-- 	"# World",
-- 	"this is another thing",
-- }))

return M
