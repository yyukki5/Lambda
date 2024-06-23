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

Private var_
Private lambdaString_ As String

Public Function Initialize(var, lambda_string As String) As Lambda
Attribute Initialize.VB_UserMemId = 0
    Call SetObjectAsBuffer(var, var_)
    lambdaString_ = lambda_string
    Set Initialize = Me
End Function

Public Function Evaluate()
    Dim eval_var, var_string As String, formula_string As String, parsed_string As String, calculated_value, evaluated_value

    On Error GoTo errEvaluate
    Call AddTag(var_, eval_var)

    Call ValidateLambdaString(lambdaString_)
    var_string = GetVarString(lambdaString_)
    formula_string = GetFormulaString(lambdaString_)
    
    parsed_string = ParseParentheses(eval_var, var_string, formula_string)
    Call TryConvertPolynominalToValue(eval_var, var_string, parsed_string, evaluated_value)
    Call RemoveTags(evaluated_value, Evaluate)
    Exit Function
    
errEvaluate:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.Evaluate()", Err.Description
End Function



'Private ---------------------------------------------
Private Sub ValidateLambdaString(lambda_string As String)
    If InStr(lambda_string, "=>") = 0 Then Err.Raise 9001, "Lambda.SetLambdaValueFormula()", "Lambda string has error. need ""=>"""
End Sub

' "x => x+1" -> "x"
Private Function GetVarString(lambda_string As String) As String
    Dim var_string As String
    
    var_string = Mid(lambda_string, 1, InStr(lambda_string, "=>") - 1)
    If Len(var_string) = 0 Then Err.Raise 9002, "Lambda.SetLambdaValueFormula()", "Lambda string has error."
    
    GetVarString = var_string
End Function

' "x => x+1" -> "x+1"
Private Function GetFormulaString(lambda_string As String) As String
    Dim formula_string As String
    
    formula_string = Mid(lambda_string, InStr(lambda_string, "=>") + 2)
    If Len(formula_string) = 0 Then Err.Raise 9002, "Lambda.SetLambdaValueFormula()", "Lambda string has error."
    
    GetFormulaString = formula_string
End Function

' example) "x.abc(1 + 1)" -> "x.abc(2)",   "(1 + 3) * 3"-> "4 * 3"
Private Function ParseParentheses(eval_var, var_string As String, formula_string As String) As String
    Dim formula_stack As Collection, current_str As String, char As String, i As Long, calculated_value
    Set formula_stack = New Collection

    For i = 1 To Len(formula_string)
        char = Mid(formula_string, i, 1)

        If char = "(" Then
            If current_str <> "" Then formula_stack.Add current_str
            current_str = ""
        
        ElseIf char = ")" Then
            ' after close parenthese ----------
            calculated_value = ConvertPolynomialToValue(eval_var, var_string, current_str)
            
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
Private Function TryConvertPolynominalToValue(eval_var, var_str As String, formula_str As String, ByRef return_value) As Boolean

    If InStrOperator(formula_str, 1) > 0 Then
        ' has operator -> polynominal
        return_value = ConvertPolynomialToValue(eval_var, var_str, formula_str)
        TryConvertPolynominalToValue = False
    Else
        ' nothing operator ->  monominal
        TryConvertPolynominalToValue = TryConvertMonomialToValue(eval_var, var_str, formula_str, return_value)
    End If
    
End Function

' example) "x.abc.def + x.abc.efg + 1"  ->  "3 + 5 + 1" -> 9
Private Function ConvertPolynomialToValue(eval_var, var_str As String, formula_str As String) As Variant
    Dim calculated_value, calculated_string
    
    If InStr(formula_str, var_str) > 0 Then
        calculated_string = ConvertToPolynomialWithoutObject(eval_var, var_str, formula_str)
    Else
        calculated_string = formula_str
    End If
    
    calculated_value = RunEvaluate(calculated_string)
    If IsError(calculated_value) Then Err.Raise 9006, "Lambda.ConvertPolynomialToValue()", "Unsupported lambda string. can not evaluate formula"
    
    ConvertPolynomialToValue = calculated_value
End Function

' example) "x.abc.def + x.abc.efg + 1"  ->  "3 + 5 + 1"
Private Function ConvertToPolynomialWithoutObject(eval_var, var_str As String, formula_str As String) As String
    Dim start_index, last_index, term_string As String, buf_val
    
    Do While InStr(formula_str, var_str) > 0
    
        start_index = InStr(formula_str, var_str)
        last_index = IIf(InStrOperator(formula_str, start_index) = 0, Len(formula_str), InStrOperator(formula_str, start_index) - 1)
        term_string = Mid(formula_str, start_index, last_index - start_index + 1)
    
        Call TryConvertMonomialToValue(eval_var, var_str, term_string, buf_val)
    
        If IsObject(buf_val) Then Err.Raise 9001, "Lambda.ConvertToPolynomialWithoutObject()", "Failed to evaluate, converted as object"
        If VarType(buf_val) > vbArray Then Err.Raise 9001, "Lambda.ConvertToPolynomialWithoutObject()", "Unsupport array for evaluate"
        
        formula_str = Replace(formula_str, term_string, buf_val)
    Loop
    
    ConvertToPolynomialWithoutObject = formula_str
End Function

' example) "x.abc.def" -> 1
Private Function TryConvertMonomialToValue(eval_var, var_str As String, monominal_string As String, ByRef return_value) As Boolean
On Error GoTo errFunction
    Dim splited_by_dot, i, index_parenthes_open As Long
    
    monominal_string = Replace(monominal_string, " ", "")
    splited_by_dot = Split(monominal_string, ".")
    
    If UBound(splited_by_dot) = 0 Then
        If InStrOperator(CStr(monominal_string), 1) > 0 Then Err.Raise 9004, "Lambda.TryConvertMonomialToValue()", "Lambda string has error.: " & monominal_string
        
        If VarType(eval_var) > vbArray Then
            TryConvertMonomialToValue = TryGetArrayValueByString(eval_var, monominal_string, return_value)
            Exit Function
        End If
        
        If Len(monominal_string) > Len(var_str) Then Err.Raise 9004, "Lambda.TryConvertMonomialToValue()", "Lambda string has error. cannot evaluate.: " & monominal_string
        If IsObject(eval_var) Then Set return_value = eval_var Else return_value = eval_var
    Else
        Set return_value = eval_var
        For i = 1 To UBound(splited_by_dot)
            If splited_by_dot(i) = "" Then Err.Raise 9004, "Lambda.TryConvertMonomialToValue()", "Lambda string has error."
            
            index_parenthes_open = InStr(splited_by_dot(i), "(")
            If index_parenthes_open > 0 Then
                Call SetCallByNameValue( _
                    called_object:=return_value, _
                    called_proc_name:=Left(splited_by_dot(i), index_parenthes_open - 1), _
                    return_value:=return_value, _
                    args:=Mid(splited_by_dot(i), index_parenthes_open + 1, InStr(splited_by_dot(i), ")") - index_parenthes_open - 1))
            Else
                Call SetCallByNameValue(return_value, CStr(splited_by_dot(i)), return_value)
            End If
        Next i
    End If
    
    AddTag return_value, return_value
    If IsObject(return_value) Then TryConvertMonomialToValue = True Else TryConvertMonomialToValue = False
    Exit Function
errFunction:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.TryConvertMonomialToValue()", Err.Description
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

