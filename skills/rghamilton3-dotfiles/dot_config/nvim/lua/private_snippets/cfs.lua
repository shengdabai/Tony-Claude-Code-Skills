local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

-- Helper function to generate header guard from filename
local function header_guard()
    local filename = vim.fn.expand("%:t:r"):upper()
    return filename .. "_H"
end

-- Helper function to get current year
local function current_year()
    return os.date("%Y")
end

return {
    -- C File Template
    s("cfs_c", fmt([[
/*
 * MIT License
 *
 * Copyright (c) {} {}
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * \file
 *   {}
 */

/*
** Include Files:
*/
{}

/*
** Global Data
*/
{}

/*
** Functions
*/
{}
]], {
        f(current_year),
        i(1, "Your Name"),
        i(2, "File description"),
        i(3, "#include \"\""),
        i(4, "/* Global variables */"),
        i(0)
    })),

    -- H File Template
    s("cfs_h", fmt([[
/*
 * MIT License
 *
 * Copyright (c) {} {}
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @file
 *
 * {}
 */

#ifndef {}
#define {}

/*
** Include Files
*/
{}

/*
** Type Definitions
*/
{}

/*
** Exported Functions
*/
{}

#endif /* {} */
]], {
        f(current_year),
        i(1, "Your Name"),
        i(2, "Header file description"),
        f(header_guard),
        f(header_guard),
        i(3, "#include \"cfe.h\""),
        i(4, "/* Type definitions */"),
        i(0),
        f(header_guard)
    })),

    -- Function header comment
    s("cfs_func", fmt([[
/*----------------------------------------------------------------
 *
 * Function: {}
 *
 * Purpose:
 *   {}
 *
 * Arguments:
 *   {}
 *
 * Returns:
 *   {}
 *
 *-----------------------------------------------------------------*/
]], {
        i(1, "FunctionName"),
        i(2, "Function purpose"),
        i(3, "None"),
        i(4, "void")
    })),
}
