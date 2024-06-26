VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Lambda"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Attribute VB_Description = "Implement simple anonymous function by string"
Option Explicit

' ----------------------------------------------------
' Project   : https://github.com/yyukki5/Lambda
' Version   : 0.3.0
' ---
' try to simply calculate by not using Evaluate().

' unsupported
'  - multi arguments
'  - multi lines
' ----------------------------------------------------

Private Const TAG_STRING_OPEN As String = "<string "
Private Const TAG_STRING_CLOSE As String = " string/>"
Private Const TAG_DATE_OPEN As String = "<date "
Private Const TAG_DATE_CLOSE As String = " date/>"

Private vars_
Private lambdaString_ As String

Public Function Initialize(var, lambda_string As String) As Lambda
Attribute Initialize.VB_UserMemId = 0
    Call ValidateLambdaString(lambda_string)
    
    lambdaString_ = GetFormulaString(lambda_string)
    Set vars_ = GetVars(var, GetVarStrings(lambda_string))
    
    Set Initialize = Me
End Function

Public Function Evaluate()
    Dim eval_var, var_string As String, formula_string As String, parsed_string As String, calculated_value, evaluated_value

    On Error GoTo errEvaluate
    formula_string = lambdaString_
    parsed_string = ParseParentheses(formula_string)
    Call TryConvertPolynominalToValue(parsed_string, evaluated_value)
    Call RemoveTags(evaluated_value, Evaluate)
    Exit Function
    
errEvaluate:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.Evaluate()", Err.Description
End Function



'Private ---------------------------------------------
Private Function IsMonomical(formula_string) As Boolean
    IsMonomical = InStrOperator(formula_string, 1) < 1
End Function


Private Function GetVars(eval_vars, var_strings) As Collection
    Dim i As Long, col As New Collection
    
    If IsArray(eval_vars) = False Then
        col.Add Array(eval_vars, var_strings)
    Else
        var_strings = Split(var_strings, ",")
        If ArrayCount(var_strings) = 1 Then
            col.Add Array(eval_vars, var_strings(LBound(var_strings)))
        Else
            For i = LBound(eval_vars) To UBound(eval_vars)
                col.Add Array(eval_vars(i), var_strings(i))
            Next i
        End If
    End If
    Set GetVars = col
End Function

Private Function GetEvalVars(var)
    If IsArray(var) Then
        GetEvalVars = var
    Else
        GetEvalVars = Array(var)
    End If
End Function

Private Sub ValidateLambdaString(lambda_string As String)
    If InStr(lambda_string, "=>") = 0 Then Err.Raise 9001, "Lambda.SetLambdaValueFormula()", "Lambda string has error. need ""=>"""
End Sub

' "x => x+1" -> "x"
Private Function GetVarStrings(lambda_string As String)
    Dim var_string As String, var_strings
    
    var_string = Mid(lambda_string, 1, InStr(lambda_string, "=>") - 1)
    var_string = Replace(Replace(Replace(var_string, "(", ""), ")", ""), " ", "")
    If Len(var_string) = 0 Then Err.Raise 9002, "Lambda.SetLambdaValueFormula()", "Lambda string has error."
            
    GetVarStrings = var_string
End Function

' "x => x+1" -> "x+1"
Private Function GetFormulaString(lambda_string As String) As String
    Dim formula_string As String
    
    formula_string = Mid(lambda_string, InStr(lambda_string, "=>") + 2)
    If Len(formula_string) = 0 Then Err.Raise 9002, "Lambda.SetLambdaValueFormula()", "Lambda string has error."
    
    GetFormulaString = formula_string
End Function

' example) "x.abc(1 + 1)" -> "x.abc(2)",   "(1 + 3) * 3"-> "4 * 3"
Private Function ParseParentheses(formula_string As String) As String
    Dim formula_stack As Collection, current_str As String, char As String, i As Long, calculated_value
    Set formula_stack = New Collection

    For i = 1 To Len(formula_string)
        char = Mid(formula_string, i, 1)

        If char = "(" Then
            If current_str <> "" Then formula_stack.Add current_str
            current_str = ""
        
        ElseIf char = ")" Then
            ' after close parenthese ----------
            calculated_value = ConvertPolynomialToValue(current_str)
            
            If formula_stack.Count > 0 Then
                current_str = formula_stack.Item(formula_stack.Count) & "(" & calculated_value & ")"
                formula_stack.Remove formula_stack.Count
            Else
                current_str = ""
            End If
            ' -----------------------------
        Else
            current_str = current_str & char
            
        End If
    Next i
    ParseParentheses = current_str
End Function

' example) "x.abc" -> x.abc,  "x.abc.def" -> 3,   "x.abc + x.abc.def" -> x.abc + 3 (error)
Private Function TryConvertPolynominalToValue(formula_str As String, ByRef return_value) As Boolean

    If IsMonomical(formula_str) = False Then
        ' has operator -> polynominal
        return_value = ConvertPolynomialToValue(formula_str)
        TryConvertPolynominalToValue = False
    Else
        ' nothing operator ->  monominal
        TryConvertPolynominalToValue = TryConvertMonomialToValue(formula_str, return_value)
    End If
    
End Function

' example) "x.abc.def + x.abc.efg + 1"  ->  "3 + 5 + 1" -> 9
Private Function ConvertPolynomialToValue(formula_str As String) As Variant
    Dim calculated_value, calculated_string
    
    If HasVariable(formula_str) Then
        calculated_string = ConvertToPolynomialWithoutObject(formula_str)
    Else
        calculated_string = formula_str
    End If
    
    calculated_value = RunEvaluate(calculated_string)
    If IsError(calculated_value) Then Err.Raise 9006, "Lambda.ConvertPolynomialToValue()", "Unsupported lambda string. can not evaluate formula"
    
    ConvertPolynomialToValue = calculated_value
End Function

Private Function HasVariable(formula_string As String) As Boolean
    Dim v, f As Boolean
    For Each v In vars_
       If InStr(formula_string, v(1)) > 0 Then HasVariable = True: Exit Function
    Next
End Function
Private Function HasVariableBy(formula_string As String, var_string As String) As Boolean
    HasVariableBy = InStr(formula_string, var_string) > 0
End Function

' example) "x.abc.def + x.abc.efg + 1"  ->  "3 + 5 + 1"
Private Function ConvertToPolynomialWithoutObject(formula_str As String) As String
    Dim monominal_string As String, buf_val, v, var_string As String
    
    On Error GoTo errFor
    Do While HasVariable(formula_str)
        For Each v In vars_
            var_string = v(1)
            If HasVariableBy(formula_str, var_string) Then
            
                monominal_string = GetMonominalStringFromPolynomial(formula_str, var_string)
                Call TryConvertMonomialToValue(monominal_string, buf_val)
            
                If IsObject(buf_val) Then Err.Raise 9001, "Lambda.ConvertToPolynomialWithoutObject()", "Failed to evaluate, converted as object"
                If VarType(buf_val) > vbArray Then Err.Raise 9001, "Lambda.ConvertToPolynomialWithoutObject()", "Unsupport array for evaluate"
                
                formula_str = Replace(formula_str, monominal_string, buf_val)
            End If
        Next
    Loop
    
    ConvertToPolynomialWithoutObject = formula_str
    Exit Function
errFor:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.ConvertToPolynomialWithoutObject()", Err.Description
End Function

Private Function GetMonominalStringFromPolynomial(polynomial_string, var_string) As String
    Dim start_index, last_index, term_string As String
    
    start_index = InStr(polynomial_string, var_string)
    last_index = IIf(InStrOperator(polynomial_string, start_index) = 0, Len(polynomial_string), InStrOperator(polynomial_string, start_index) - 1)
    term_string = Mid(polynomial_string, start_index, last_index - start_index + 1)
    
    GetMonominalStringFromPolynomial = term_string
End Function


' example) "x.abc.def" -> 1
Private Function TryConvertMonomialToValue(monominal_string As String, ByRef return_value) As Boolean
On Error GoTo errFunction
    Dim splited_by_dot() As String, i, eval_var, var_str As String, v
    
    If HasOperator(monominal_string) Then Err.Raise 9004, "Lambda.TryConvertMonomialToValue()", "Lambda string has error.: " & monominal_string
    
    monominal_string = Replace(monominal_string, " ", "")
    If HasChildString(monominal_string) Then
        splited_by_dot = Split(monominal_string, ".")
        For Each v In vars_
            If HasVariableBy(monominal_string, (v(1))) Then
                Set return_value = v(0)
                For i = 1 To UBound(splited_by_dot)
                    If IsMethodPropOrArrayString(splited_by_dot(i)) Then
                        Call SetCallByNameValue(return_value, GetProcName(splited_by_dot(i)), return_value, ExtructProcParamString(splited_by_dot(i)))
                    Else
                        Call SetCallByNameValue(return_value, splited_by_dot(i), return_value)
                    End If
                Next i
            End If
        Next
    Else
        For Each v In vars_
            If HasVariableBy(monominal_string, (v(1))) Then
                If IsMethodPropOrArrayString(monominal_string) Then
                    If IsArray(v(0)) Then ' arr(1)
                        TryConvertMonomialToValue = TryGetArrayValueByString(v(0), monominal_string, return_value)
                    Else
                        Err.Raise 9004, "Lambda.TryConvertMonomialToValue()", "Lambda string has error. cannot evaluate.: " & monominal_string
                    End If
                ElseIf monominal_string <> v(1) Then
                    Err.Raise 9004, "Lambda.TryConvertMonomialToValue()", "Lambda string has error. cannot evaluate.: " & monominal_string
                Else ' x, 123
                    SetObjectAsBuffer v(0), return_value
                End If
            End If
        Next
    End If

    AddTag return_value, return_value
    If IsObject(return_value) Then TryConvertMonomialToValue = True Else TryConvertMonomialToValue = False
    Exit Function
errFunction:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.TryConvertMonomialToValue()", Err.Description
End Function

Private Function HasChildString(monomical_string) As Boolean
    HasChildString = (ArrayCount(Split(monomical_string, ".")) <> 1)
End Function



Private Function SetCallByNameValue(called_object, called_proc_name As String, ByRef return_value, Optional args As Variant) As Boolean
        Dim re
    If IsMissing(args) Then
        On Error GoTo errGetWithoutArg
        Call SetObjectAsBuffer(CallByName(called_object, called_proc_name, VbGet), return_value)
        SetCallByNameValue = IsObject(return_value)
        Exit Function
errGetWithoutArg:
        If Err.Number = 450 Then
            Call SetObjectAsBuffer(CallByName(called_object, called_proc_name, VbMethod), return_value)
            SetCallByNameValue = IsObject(return_value)
        ElseIf Err.Number = 438 Then
            Err.Raise 9001, "Lambda.SetCallByNameValue()", "Not implemented property: " & TypeName(called_object) & "." & called_proc_name
        Else
            Err.Raise Err.Number, Err.Source, Err.Description
        End If
    Else
        On Error GoTo errGetWitArg
        Call SetObjectAsBuffer(CallByName(called_object, called_proc_name, VbGet, args), return_value)
        SetCallByNameValue = IsObject(return_value)
        Exit Function
errGetWitArg:
        If Err.Number = 451 Then
            Call SetObjectAsBuffer(CallByName(called_object, called_proc_name, VbGet), re)
            If VarType(re) > vbArray Then
                SetCallByNameValue = TryGetArrayValueByParamstersString(re, args, return_value)
            Else
                Err.Raise Err.Number, Err.Source & "at Lambda.SetCallByNameValue(): Get method with arguments, not array ", Err.Description
            End If
        ElseIf Err.Number = 450 Then
            Call SetObjectAsBuffer(CallByName(called_object, called_proc_name, VbMethod, args), return_value)
            SetCallByNameValue = IsObject(return_value)
        ElseIf Err.Number = 438 Then
            Err.Raise 9001, "Lambda.SetCallByNameValue()", "Not implemented property: " & TypeName(called_object) & "." & called_proc_name
        Else
            Err.Raise Err.Number, Err.Source, Err.Description
        End If
    End If
    Exit Function
End Function

Private Function SetObjectAsBuffer(ByRef unverified_value, ByRef buffer_value)
    Dim isObj As Boolean
    isObj = IsObject(unverified_value)
    If isObj Then
        Set buffer_value = unverified_value
        SetObjectAsBuffer = True
    Else
        buffer_value = unverified_value
        SetObjectAsBuffer = False
    End If
End Function

Private Function HasOperator(string_has_operator As String) As Boolean
    HasOperator = InStrOperator(string_has_operator, 1) > 0
End Function

Private Function InStrOperatorBy(string_has_operator, start_index, o) As Long
    Dim i As Long, str As String
    
    str = Mid(string_has_operator, start_index)
    For i = start_index To Len(string_has_operator)
        i = i + GetTagLength(str)
        str = Mid(string_has_operator, i)
        If Left(str, Len(o)) = o Then InStrOperatorBy = i: Exit Function
    Next i
    InStrOperatorBy = 0
End Function

Private Function InStrOperator(string_has_operator, start_index) As Long
    Dim i As Long, str As String
    
    str = Mid(string_has_operator, start_index)
    For i = start_index To Len(string_has_operator)
        i = i + GetTagLength(str)
        str = Mid(string_has_operator, i)
        If IsOperator(str) Then InStrOperator = i: Exit Function
    Next i
    InStrOperator = 0
End Function

Private Function IsOperator(operator_string) As Boolean
    IsOperator = True
        
    Dim o
    For Each o In Operators
        If Left(operator_string, Len(o)) = o Then Exit Function
    Next
    
    IsOperator = False
End Function

Private Property Get Operators()
    Operators = Array(" Imp ", " Eqv ", " Xor ", " Or ", " And ", " Not ", _
                      " Is ", " Like ", "<=", ">=", ">", "<", "<>", "=", _
                      "&", "+", "-", " Mod ", "\", "*", "/", " ^ ")
End Property


' "1 + 2 * 2"  -> 1 + 4 -> 5 (calculate each operators.(recursively called by self))
Private Function RunEvaluate(string_has_operator)
    Dim i As Long, o, vl, vr

On Error GoTo errCalculate
    
    For Each o In Operators
    
        i = InStrOperatorBy(string_has_operator, 1, o)
        If i < 1 Then GoTo nextloop
        
        ' found matched operator
        vl = RunEvaluate(Left(string_has_operator, i - 1))
        vr = RunEvaluate(Mid(string_has_operator, i + Len(o)))
        RunEvaluate = CalculateOperator(operator_string:=o, left_value:=Trim(vl), right_value:=Trim(vr))
        Exit Function
nextloop:
    Next
    
    ' not found matched operator
    RunEvaluate = string_has_operator
    Exit Function
    
errCalculate:
    Err.Raise 9001, Err.Source & vbCrLf & " at Lambda.RunEvaluate(" & string_has_operator & "," & o & ")", Err.Description & vbCrLf & "failed to calculate by operator: " & o
End Function

' 1 + 4  -> 5
Private Function CalculateOperator(operator_string, left_value, right_value)
    Dim calculated_value, removed_tag_left, removed_tag_right
    RemoveTags left_value, left_value
    RemoveTags right_value, right_value

On Error GoTo errCalc
    Select Case operator_string
        Case "<=": calculated_value = left_value <= right_value
        Case ">=": calculated_value = left_value >= right_value
        Case ">": calculated_value = left_value > right_value
        Case "<": calculated_value = left_value < right_value
        Case "<>": calculated_value = left_value <> right_value
        Case "=": calculated_value = left_value = right_value
        Case "&": calculated_value = left_value & right_value
        Case "+": calculated_value = left_value + right_value
        Case "-": calculated_value = left_value - right_value
        Case "*": calculated_value = left_value * right_value
        Case "/": calculated_value = left_value / right_value
        Case "\": calculated_value = left_value \ right_value
        Case " ^ ": calculated_value = left_value ^ right_value
        Case " Mod ": calculated_value = left_value Mod right_value
        Case " Imp ": calculated_value = left_value Imp right_value
        Case " Eqv ": calculated_value = left_value Eqv right_value
        Case " Xor ": calculated_value = left_value Xor right_value
        Case " Or ": calculated_value = left_value Or right_value
        Case " And ": calculated_value = left_value And right_value
        Case " Not ": calculated_value = Not left_value
        Case " Like ": calculated_value = left_value Like right_value
        Case " Is ": calculated_value = left_value Is right_value
    End Select
    
    Dim calculated_value_with_tag
    AddTag calculated_value, calculated_value_with_tag
    CalculateOperator = calculated_value_with_tag
    Exit Function
errCalc:
    Err.Raise 9001, "Lambda.CalculateOperator()", "formula string has error : " & left_value & " " & operator_string & " " & right_value
End Function


Private Function AddTag(unverfied_value, re_value)
    If IsObject(unverfied_value) Then
        Set re_value = unverfied_value
    ElseIf IsDate(unverfied_value) Then
        re_value = AddTagAs(unverfied_value, TAG_DATE_OPEN, TAG_DATE_CLOSE)
    ElseIf VarType(unverfied_value) = vbBoolean Then
        re_value = unverfied_value
    ElseIf IsNumeric(unverfied_value) Then
        re_value = val(unverfied_value)
    ElseIf VarType(unverfied_value) = vbString Then
        re_value = AddTagAs(unverfied_value, TAG_STRING_OPEN, TAG_STRING_CLOSE)
    Else
        re_value = unverfied_value
    End If
End Function

Private Function RemoveTags(unverfied_value, re_value)
    If IsObject(unverfied_value) Then
        Set re_value = unverfied_value
    ElseIf VarType(unverfied_value) = vbBoolean Then
        re_value = unverfied_value
    ElseIf IsNumeric(unverfied_value) Then
        re_value = val(unverfied_value)
    ElseIf VarType(unverfied_value) = vbString Then
        If HasTagBy(unverfied_value, TAG_DATE_OPEN) Then re_value = DateValue(RemoveTagAs(unverfied_value, TAG_DATE_OPEN, TAG_DATE_CLOSE))
        If HasTagBy(unverfied_value, TAG_STRING_OPEN) Then re_value = RemoveTagAs(unverfied_value, TAG_STRING_OPEN, TAG_STRING_CLOSE)
    Else
        re_value = unverfied_value
'        Debug.Print "(RemoveTags()) unexpected value:" & unverfied_value
    End If
End Function

Private Function HasTagBy(str, ope) As Boolean
    If Left(str, Len(ope)) = ope Then HasTagBy = True Else HasTagBy = False
End Function

Private Function AddTagAs(converting_string, tag_open, tag_close) As String
    If Left(converting_string, 1) = "<" And Right(converting_string, 2) = "/>" Then AddTagAs = converting_string Else AddTagAs = tag_open & converting_string & tag_close
End Function

Private Function RemoveTagAs(deconverting_string, tag_open, tag_close)
    If Left(deconverting_string, 1) = "<" And Right(deconverting_string, 2) = "/>" Then RemoveTagAs = Replace(Replace(deconverting_string, tag_open, ""), tag_close, "") Else RemoveTagAs = deconverting_string
End Function

Private Function GetTagLength(str) As Long
    GetTagLength = 0
    If Left(str, Len("<")) = "<" Then GetTagLength = InStr(str, "/>") + Len("/>") - 1
End Function

' related arrays -------------------------------
Private Function TryGetArrayValueByString(arr, array_sting, reval) As Boolean
    Dim pstr As String, parr
    If IsArrayHasArgument(array_sting) Then
        pstr = ExtructArrayParametersString(array_sting)
        TryGetArrayValueByString = TryGetArrayValueByParamstersString(arr, pstr, reval)
    Else
        reval = arr
        TryGetArrayValueByString = True
    End If
End Function
Private Function TryGetArrayValueByParamstersString(arr, parameter_sting, reval) As Boolean
        Dim pstr As String, parr
        parr = GetArrayParametersByString(parameter_sting)
        TryGetArrayValueByParamstersString = TryGetArrayValue(arr, parr, reval)
End Function
Private Function IsArrayHasArgument(array_string) As Boolean
    IsArrayHasArgument = InStr(array_string, "(") > 0
End Function
Private Function ExtructArrayParametersString(array_sting) As String
    ExtructArrayParametersString = Mid(array_sting, InStr(array_sting, "(") + 1, InStr(array_sting, ")") - 1 - InStr(array_sting, "("))
End Function
Private Function GetArrayParametersByString(parameters_sting)
    GetArrayParametersByString = Split(parameters_sting, ",")
End Function
Private Function TryGetArrayValue(arr, p, reval) As Boolean
On Error GoTo errArray
    Dim rnk As Long: rnk = UBound(p) - LBound(p) + 1
    Select Case rnk
        Case 1: TryGetArrayValue = SetObjectAsBuffer(arr(p(0)), reval)
        Case 2: TryGetArrayValue = SetObjectAsBuffer(arr(p(0), p(1)), reval)
        Case 3: TryGetArrayValue = SetObjectAsBuffer(arr(p(0), p(1), p(2)), reval)
        Case Else
            Err.Raise 9009, Err.Source & vbCrLf & "at Lambda.TryGetArrayValue()", "unsupported dimension array"
    End Select
    Exit Function
errArray:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.TryGetArrayValue()", Err.Description
End Function

Private Function ArrayCount(arr, Optional d As Long = 1) As Long
    ArrayCount = UBound(arr, d) - LBound(arr, d) + 1
End Function

Private Function IsMethodPropOrArrayString(monomical_string) As Boolean
    IsMethodPropOrArrayString = InStr(monomical_string, "(") > 0
End Function


Private Function GetProcName(function_string) As String
    Dim index_parenthes_open
    index_parenthes_open = InStr(function_string, "(")
    If index_parenthes_open > 0 Then GetProcName = Left(function_string, index_parenthes_open - 1) Else GetProcName = function_string
End Function

Private Function ExtructProcParamString(function_string) As String
    Dim index_parenthes_open
    index_parenthes_open = InStr(function_string, "(")
    ExtructProcParamString = Mid(function_string, index_parenthes_open + 1, InStr(function_string, ")") - index_parenthes_open - 1)
End Function
