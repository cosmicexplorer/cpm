numsOnly = /^[0-9]+$/g

VERSION_STRING_LENGTH = 3

indexAndGetNumeric = (i, arrs...) -> arrs.map (arr) ->
  arr[i].replace /[^0-9]/g, ""

module.exports =

  # preserve first argument of function for async calls with error arg
  curryAsync: (beginArgs..., fn) -> (args...) ->
    fn args[0], beginArgs..., args[1..]...

  compareVersionStrings: (version, version_spec) ->
    return no unless version_spec? and version?
    nums = version.split '.'
    spec = version_spec.split '.'
    return no unless nums.length is spec.length is VERSION_STRING_LENGTH
    [ind, comparison] = do ->
      for i in [0..(VERSION_STRING_LENGTH - 1)] by 1
        return [i, spec[i].replace /[0-9]/g, ""] unless spec[i].match numsOnly
      [null, null]
    try do ->
      flag = no
      for i in [ind..(VERSION_STRING_LENGTH - 1)] by 1
        [n, s] = indexAndGetNumeric i, nums, spec
        throw -1 unless n and s
        switch comparison
          when '<='
            if n < s then return yes else if n > s then return no
          when '>='
            if n > s then return yes else if n < s then return no
          when '<'
            if n > s then return no else if n < s then flag = yes
          when '>'
            if n < s then return no else if n > s then flag = yes
          else return no
      switch comparison
        when '<=', '>=' then yes
        when '>', '<' then flag
    catch then return no
