-- TOML Structure Validator for Hammerflow
-- Validates TOML files before parsing to catch common structural issues

local function validateTomlStructure(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return false, "Could not open file: " .. filepath
  end
  
  local issues = {}
  local warnings = {}
  local lineNum = 0
  local inMultilineString = false
  local multilineDelimiter = nil
  local firstTableSection = nil
  local firstTableLine = nil
  local keysAfterTable = {}
  local seenKeys = {}  -- Track duplicate keys at root level
  local currentSection = nil  -- Track current table section
  local sectionKeys = {}  -- Track keys within sections
  
  for line in file:lines() do
    lineNum = lineNum + 1
    
    -- Handle multi-line strings
    if inMultilineString then
      -- Check for the ending delimiter
      if (multilineDelimiter == "'''" and line:find("'''")) or
         (multilineDelimiter == "]]]" and line:find("%]%]%]")) then
        inMultilineString = false
        multilineDelimiter = nil
      end
      goto continue
    end
    
    -- Check for multi-line string start
    local tripleQuote = line:match("^%s*%w+%s*=%s*(''')")
    local tripleDoubleQuote = line:match("^%s*%w+%s*=%s*(%[%[%[)")
    if tripleQuote then
      inMultilineString = true
      multilineDelimiter = "'''"
      goto continue
    elseif tripleDoubleQuote then
      inMultilineString = true
      multilineDelimiter = "]]]"
      goto continue
    end
    
    -- Skip empty lines and comments
    if line:match("^%s*$") or line:match("^%s*#") then
      goto continue
    end
    
    -- Check for table section [section] or [section.subsection]
    local tableSection = line:match("^%s*%[([%w%.%-%_]+)%]%s*$") or 
                         line:match("^%s*%[\"([^\"]+)\"%]%s*$") or
                         line:match("^%s*%['([^']+)'%]%s*$")
    if tableSection then
      if not firstTableSection then
        firstTableSection = tableSection
        firstTableLine = lineNum
      end
      currentSection = tableSection
      if not sectionKeys[currentSection] then
        sectionKeys[currentSection] = {}
      end
      goto continue
    end
    
    -- Check for array of tables [[section]]
    local arraySection = line:match("^%s*%[%[([%w%.%-%_]+)%]%]%s*$")
    if arraySection then
      if not firstTableSection then
        firstTableSection = "[[" .. arraySection .. "]]"
        firstTableLine = lineNum
      end
      currentSection = arraySection
      goto continue
    end
    
    -- Check for key = value pairs
    -- Match both quoted and unquoted keys
    local key = line:match("^%s*([%w%-%_]+)%s*=") or 
                line:match('^%s*"([^"]+)"%s*=') or
                line:match("^%s*'([^']+)'%s*=")
    
    if key then
      -- Check if this is an inline table
      local isInlineTable = line:match("=%s*{")
      
      if currentSection then
        -- We're inside a table section
        if sectionKeys[currentSection][key] then
          table.insert(issues, string.format(
            "Line %d: Duplicate key '%s' in section [%s] (first defined at line %d)",
            lineNum, key, currentSection, sectionKeys[currentSection][key]
          ))
        else
          sectionKeys[currentSection][key] = lineNum
        end
      else
        -- We're at root level
        if firstTableSection and not isInlineTable then
          -- This is a root-level key after a table section
          table.insert(keysAfterTable, {
            key = key,
            line = lineNum,
            afterSection = firstTableSection,
            afterLine = firstTableLine
          })
        end
        
        -- Check for duplicate root keys
        if seenKeys[key] then
          table.insert(issues, string.format(
            "Line %d: Duplicate key '%s' at root level (first defined at line %d)",
            lineNum, key, seenKeys[key]
          ))
        else
          seenKeys[key] = lineNum
        end
      end
    end
    
    -- Check for common syntax errors
    -- Only check for unclosed quotes in simple cases
    -- Skip lines that have mixed quote types (like "text with 'apostrophe'")
    local hasSingleInDouble = line:match('"[^"]*\'[^"]*"')
    local hasDoubleInSingle = line:match("'[^']*\"[^']*'")
    
    if not hasSingleInDouble and not hasDoubleInSingle then
      -- Unclosed quotes
      local singleQuotes = select(2, line:gsub("'", ""))
      local doubleQuotes = select(2, line:gsub('"', ''))
      -- Exclude escaped quotes
      local escapedSingle = select(2, line:gsub("\\'", ""))
      local escapedDouble = select(2, line:gsub('\\"', ''))
      
      if (singleQuotes - escapedSingle) % 2 ~= 0 then
        table.insert(warnings, string.format(
          "Line %d: Possible unclosed single quote",
          lineNum
        ))
      end
      if (doubleQuotes - escapedDouble) % 2 ~= 0 then
        table.insert(warnings, string.format(
          "Line %d: Possible unclosed double quote",
          lineNum
        ))
      end
    end
    
    -- Check for invalid table names (basic check)
    local invalidTable = line:match("^%s*%[([^%]]+)%]")
    if invalidTable then
      -- Check if it's a quoted table name
      local quotedContent = invalidTable:match('^"([^"]+)"$') or invalidTable:match("^'([^']+)'$")
      
      if quotedContent then
        -- For quoted table names, allow any characters inside quotes
        -- This is valid TOML syntax
      elseif not invalidTable:match("^[%w%.%-%_]+$") then
        -- For bare table names, enforce strict character rules
        table.insert(issues, string.format(
          "Line %d: Invalid table name '[%s]' - contains invalid characters",
          lineNum, invalidTable
        ))
      end
    end
    
    ::continue::
  end
  
  file:close()
  
  -- Report findings
  local hasErrors = #issues > 0 or #keysAfterTable > 0
  
  if hasErrors or #warnings > 0 then
    print(string.format("\n=== TOML Validation Report for %s ===", filepath))
    
    -- Critical issues that will cause parsing problems
    if #keysAfterTable > 0 then
      print("\n❌ CRITICAL: Individual keys defined after table sections (will be ignored):")
      for _, info in ipairs(keysAfterTable) do
        print(string.format("   Line %d: %s = ... (after [%s] on line %d)",
          info.line, info.key, info.afterSection, info.afterLine))
      end
      print("\n   FIX: Move these keys before line " .. firstTableLine)
    end
    
    -- Other structural issues
    if #issues > 0 then
      print("\n❌ ERRORS:")
      for _, issue in ipairs(issues) do
        print("   " .. issue)
      end
    end
    
    -- Warnings (might not break parsing but could indicate problems)
    if #warnings > 0 then
      print("\n⚠️  WARNINGS:")
      for _, warning in ipairs(warnings) do
        print("   " .. warning)
      end
    end
    
    print(string.format("\n=== End of validation report ===\n"))
  end
  
  -- Return success even with warnings - let TOML parser handle actual syntax errors
  return true, hasErrors and "Validation completed with errors" or "Validation completed successfully"
end

return validateTomlStructure