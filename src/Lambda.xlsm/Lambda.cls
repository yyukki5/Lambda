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
' Version   : 0.4.0
' ---
' try to simply calculate by not using Evaluate().

' unsupported
'  - multi lines
' ----------------------------------------------------

Private Const TAG_STRING_OPEN As String = "<string "
Private Const TAG_STRING_CLOSE As String = " string/>"
Private Const TAG_DATE_OPEN As String = "<date "
Private Const TAG_DATE_CLOSE As String = " date/>"

Private vars_
Private lambdaString_ As String

Private Enum lmVarType
    lmVarTypeVar
    lmVarTypeName
End Enum

Private Enum lmValueType
    lmIsOpe
    lmValue
End Enum

Private Enum lmPolynominalParseCase
    lmBlank
    lmOpe
    lmMono
    lmPoly
End Enum


Public Function Initialize(var, lambda_string As String) As Lambda
Attribute Initialize.VB_UserMemId = 0
    Call ValidateLambdaString(lambda_string)
    
    lambdaString_ = GetFormulaString(lambda_string)
    Set vars_ = GetVars(var, GetVarStrings(lambda_string))
    
    Set Initialize = Me
End Function

Public Function Evaluate()

On Error GoTo errLabel
    Call ParsePolynominal(lambdaString_, Evaluate)
    Exit Function
    
errLabel:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.Evaluate()", Err.Description
End Function



'Private ---------------------------------------------
Private Function ParsePolynominal(polynominal_string As String, reval) As Variant
    Dim polynominal_collection As Collection, polynominal_collection_re As New Collection, p
    
On Error GoTo errLabel
    Set polynominal_collection = SplitPolynominal(polynominal_string)
    
    For Each p In polynominal_collection
        Select Case p(lmIsOpe)
        Case lmPoly
            Call ParsePolynominal((p(lmValue)), p(lmValue))
        Case lmMono
            Call ConvertMonominalStringToValue((p(lmValue)), p(lmValue))
        End Select
        Call polynominal_collection_re.Add(p)
    Next
    
    Call EvaluetePolynominalCollection(polynominal_collection_re, reval)
    Exit Function

errLabel:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.ParsePolynominal(" & polynominal_string & ")", Err.Description
End Function


Private Function ConvertMonominalStringToValue(monominal_string As String, reval) As Variant
    Dim monominal_collection As Collection, tmp, m, p
    
    Set monominal_collection = SplitMonominalStringByDot(monominal_string)
    For Each m In monominal_collection
        Call SetObjectAsBuffer(ConvertMonominalObjectToValue(m, p), p)
    Next
    Call SetObjectAsBuffer(p, reval)
    
End Function

Private Function ConvertMonominalObjectToValue(object_string, parent_object) As Variant
    Dim formula_string As String, inner_string As String, inner_collection As Collection, inner_collection_re As New Collection, ic, tmp
    
    Call ExtructProcNameParamString(object_string, formula_string, inner_string)
    Set inner_collection = SplitByComma(inner_string)
    
    For Each ic In inner_collection
        Call ParsePolynominal((ic), tmp)
        Call inner_collection_re.Add(tmp)
    Next ic
    Set inner_collection = inner_collection_re
    
    Call EvaluateMonominalObject(formula_string, inner_collection, parent_object, ConvertMonominalObjectToValue)

End Function

Private Function EvaluateMonominalObject(formula_string As String, inner_collection As Collection, parent_object, ByRef reval) As Variant

On Error GoTo errLabel
    formula_string = Trim(formula_string)
    
    If IsNullOrEmptyOrNothing(parent_object) Then
    
        If HasVariable(formula_string) Then
            Call GetVarByVarName(formula_string, reval)
            
            If IsArray(reval) And inner_collection.Count > 0 Then
                Dim tmp_arr
                tmp_arr = reval: reval = Null
                Call GetArrayElement(tmp_arr, inner_collection, reval)
            End If
        
        Else
            If IsMethodPropOrArrayString(formula_string) Then
                Call RunMethod(formula_string, inner_collection, reval)
            Else
                reval = formula_string
            End If
        End If
    
    Else
        Call GetChildVar(formula_string, inner_collection, parent_object, reval)
    End If
    Exit Function
    
errLabel:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.EvaluateMonominalObject()", Err.Description
End Function

Private Function GetChildVar(formula_string As String, inner_collection As Collection, parent_object, reval)
    Dim arguments, err_num As Long, err_des, tmp
    
    If inner_collection.Count > 0 Then
        
        On Error Resume Next
        Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet), reval)
        Err.Clear
        
        If IsArray(reval) Then
            Dim tmp_arr
            tmp_arr = reval: reval = Null
            Call GetArrayElement(tmp_arr, inner_collection, reval)
        ElseIf IsEmpty(reval) Then
            arguments = CollectionToArray(inner_collection)
            Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet, arguments), reval)
            If Err.Number = 450 Then
                Err.Clear
                Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbMethod, arguments), reval)
            End If
            If Err.Number <> 0 Then err_num = Err.Number: err_des = Err.Description
            On Error GoTo 0:    If err_num <> 0 Then Call Err.Raise(err_num, "Lambda.GetChildVar()", err_des)
        Else
            On Error GoTo 0:    Call Err.Raise(11000, "Lambda.GetChildVar()", "undefined error")
        End If
    Else
    
        On Error Resume Next
        Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet), reval)
        If Err.Number = 450 Then
            Err.Clear
            Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbMethod), reval)
        End If
        If Err.Number <> 0 Then err_num = Err.Number: err_des = Err.Description
        On Error GoTo 0:   If err_num <> 0 Then Call Err.Raise(err_num, "GetChildVar()", err_des)
    End If
    
    
End Function

Private Function GetVarByVarName(formula_string, reval)
    Dim v
    
    For Each v In vars_
        If formula_string = v(lmVarTypeName) Then
            Call SetObjectAsBuffer(v(lmVarTypeVar), reval)
            Exit Function
        End If
    Next
    Call Err.Raise(11000, "Lambda.GetVarByVarName()", "not found variable")
    
End Function

Private Function RunMethod(method_name As String, ic As Collection, reval)
    
    Select Case ic.Count
    Case 0:   Call SetObjectAsBuffer(Application.Run(method_name), reval)
    Case 1:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1)), reval)
    Case 2:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2)), reval)
    Case 3:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3)), reval)
    Case 4:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3), ic(4)), reval)
    Case 5:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3), ic(4), ic(5)), reval)
    Case 6:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3), ic(4), ic(5), ic(6)), reval)
    Case Else
        Call Err.Raise(11000, "Lambda.RunMethod()", "arguments is over")
    End Select
    
End Function

Private Function GetArrayElement(arr, ic As Collection, reval)
        
    Select Case ic.Count
    Case 1:   Call SetObjectAsBuffer(arr(ic(1)), reval)
    Case 2:   Call SetObjectAsBuffer(arr(ic(1), ic(2)), reval)
    Case 3:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3)), reval)
    Case 4:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3), ic(4)), reval)
    Case 5:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3), ic(4), ic(5)), reval)
    Case 6:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3), ic(4), ic(5), ic(6)), reval)
    Case Else
        Call Err.Raise(11000, "Lambda.GetArrayElement()", "arguments is over")
    End Select
    
End Function

Private Function SplitMonominalStringByDot(ByVal monominal_strring) As Collection
    Dim cntPar As Long, i As Long, right_string, left_string
    Dim monominal_collection As New Collection
    
    Let right_string = monominal_strring
    Do While right_string <> ""
        Let i = 1
        i = i + GetTagSpanLengthWithStarted(right_string)
        Select Case Mid(right_string, i, 1)
        Case "(":             Let cntPar = cntPar + 1
        Case ")":             Let cntPar = cntPar - 1
        End Select
        
        Let left_string = left_string & Left(right_string, i)
        Let right_string = Mid(right_string, i + 1)
        If cntPar = 0 And IsStartWithDot(right_string) Then
            Call monominal_collection.Add(left_string)
            left_string = ""
            right_string = Mid(right_string, i + 1)
        End If
    Loop
    Call monominal_collection.Add(left_string)
    Set SplitMonominalStringByDot = monominal_collection
    
End Function

Private Function IsStartWithDot(str) As Boolean

    If Left(str, 1) = "." Then IsStartWithDot = True Else IsStartWithDot = False
    
End Function

Private Function SplitPolynominal(ByVal polynoimnal_string As String) As Collection
    Dim polynoimal_collection As New Collection
    Dim left_string As String, right_string As String, ope As String
    
    Let right_string = polynoimnal_string
    Do While right_string <> ""
        Select Case SplitPolynoinalString(right_string, left_string, right_string, ope)
        Case lmOpe:        Call polynoimal_collection.Add(Array(lmOpe, ope))
        Case lmMono:     Call polynoimal_collection.Add(Array(lmMono, left_string))
        Case lmPoly:        Call polynoimal_collection.Add(Array(lmPoly, GetInnerStringsClosedBy(left_string, "(")))
        End Select
    Loop
    Set SplitPolynominal = polynoimal_collection

End Function

Private Function SplitPolynoinalString(str As String, left_string As String, right_string As String, ope As String) As lmPolynominalParseCase
    
    If IsStartedWithTags(str) Then
        Let SplitPolynoinalString = lmMono
        Call SplitFirstOperator(str, left_string, right_string)
        Let ope = ""
    ElseIf IsOperator(str) Then
        Call SplitByOperator(str, ope, right_string)
        Let left_string = ""
        Let SplitPolynoinalString = lmOpe
    ElseIf Mid(str, 1, 1) = " " Then
        Let right_string = Mid(str, 1 + 1)
        SplitPolynoinalString = lmBlank
    ElseIf IsParenthese(str) Then
        Let SplitPolynoinalString = lmPoly
        Call SplitFirsrParenthese(str, left_string, right_string)
        Let ope = ""
    Else
        Let SplitPolynoinalString = lmMono
        Call SplitFirstOperator(str, left_string, right_string)
        Let ope = ""
    End If

End Function

Private Function SplitFirsrParenthese(ByVal str, left_string, right_string)
    Dim cntPar As Long, i As Long

    right_string = str
    For i = 1 To Len(str)
        i = i + GetTagSpanLengthWithStarted(right_string)
        Select Case Mid(str, i, 1)
        Case "(":             Let cntPar = cntPar + 1
        Case ")":             Let cntPar = cntPar - 1
        Case Else
        End Select
        
        Let left_string = Left(str, i)
        Let right_string = Mid(str, i + 1)
        If cntPar = 0 Then Exit Function
    Next i

End Function

Private Function IsParenthese(str) As Boolean
    If Left(str, 1) = "(" Then IsParenthese = True Else IsParenthese = False
End Function

Private Function SplitFirstOperator(ByVal str As String, left_string As String, right_string As String)
    Dim cntPar As Long, i As Long

    right_string = str
    For i = 1 To Len(str)
        i = i + GetTagSpanLengthWithStarted(right_string)
        Select Case Mid(str, i, 1)
        Case "(":             Let cntPar = cntPar + 1
        Case ")":             Let cntPar = cntPar - 1
        Case Else
        End Select
        
        Let left_string = Left(str, i)
        Let right_string = Mid(str, i + 1)
        If cntPar = 0 And IsOperator(right_string) Then Exit Function
    Next i

End Function


Private Function SplitByComma(str As String) As Collection
    Dim i As Long, col As New Collection, tmp As String
    
    For i = 1 To Len(str)
        If Mid(str, i, 1) = "," Then
            col.Add tmp
            tmp = ""
        Else
            tmp = tmp & Mid(str, i, 1)
        End If
    Next i
    If tmp <> "" Then col.Add tmp
    Set SplitByComma = col
End Function

Private Function SplitByOperator(str, ope, right_str)
    ope = TakeOperator(str)
    right_str = Mid(str, Len(ope) + 1)
End Function

Private Function EvaluetePolynominalCollection(pc As Collection, reval)
    
    If pc.Count = 0 Then
        Exit Function
    ElseIf pc.Count = 1 Then
        SetObjectAsBuffer pc(1)(1), reval
        Call RemoveTags(reval, reval)
        Exit Function
    Else
        reval = RunEvaluatePolynominalCollectionRec(pc)
    End If
    
End Function

' "1 + 2 * 2"  -> 1 + 4 -> 5 (calculate each operators.(recursively called by self))
Private Function RunEvaluatePolynominalCollectionRec(pc As Collection)
    Dim i As Long, o, vl, vr
    Dim left_col As Collection, right_col As Collection
    Dim re As Variant

On Error GoTo errCalculate
    
    If pc.Count = 0 Then SetObjectAsBuffer re, RunEvaluatePolynominalCollectionRec: Exit Function
    If pc.Count = 1 Then SetObjectAsBuffer pc(1)(1), RunEvaluatePolynominalCollectionRec: Exit Function
    
    For Each o In Operators
        
        If SplitCollectionByOpartor(pc, o, left_col, right_col) = False Then GoTo nextloop
        
        ' found matched operator
        vl = RunEvaluatePolynominalCollectionRec(left_col)
        vr = RunEvaluatePolynominalCollectionRec(right_col)
        RunEvaluatePolynominalCollectionRec = CalculateOperator(operator_string:=o, left_value:=vl, right_value:=vr)
        Exit Function
nextloop:
    Next
    
    ' not found matched operator
errCalculate:
    Err.Raise 9001, Err.Source & vbCrLf & " at Lambda.RunEvaluatePolynominalCollectionRec" ' (" & string_has_operator & "," & o & ")", Err.Description & vbCrLf & "failed to calculate by operator: " & o
End Function


Private Function SplitCollectionByOpartor(pc As Collection, ope, left_col As Collection, right_col As Collection) As Boolean
    Dim c, f As Boolean, left_c As New Collection, right_c As New Collection
    f = False
    For Each c In pc
        If c(lmIsOpe) = lmOpe Then If c(lmValue) = ope And f = False Then f = True: GoTo nextloop
        If f = False Then left_c.Add c Else right_c.Add c
nextloop:
    Next
    
    Set left_col = left_c
    Set right_col = right_c
    SplitCollectionByOpartor = f
    
End Function

Private Function SetObjectAsEmpty(reval)
    Dim re As Variant
    If IsObject(reval) Then Set reval = re Else reval = re
End Function

Private Function GetVars(eval_vars, var_strings) As Collection
    Dim i As Long, col As New Collection
    
    var_strings = Split(var_strings, ",")
    
    If IsArray(eval_vars) = False Then
        col.Add Array(eval_vars, var_strings(LBound(var_strings)))
    
    ElseIf IsArray(eval_vars) And ArrayCount(var_strings) = 1 Then
        col.Add Array(eval_vars, var_strings(LBound(var_strings)))
    
    ElseIf IsArray(eval_vars) And ArrayCount(var_strings) > 1 Then
        For i = LBound(eval_vars) To UBound(eval_vars)
            col.Add Array(eval_vars(i), var_strings(i))
        Next i
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
    formula_string = AddTags(formula_string)
    
    GetFormulaString = formula_string
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
    CalculateOperator = calculated_value
    Exit Function
errCalc:
    Err.Raise 9001, "Lambda.CalculateOperator()", "formula string has error : " & left_value & " " & operator_string & " " & right_value
End Function



' ---- element functions ---------------------------------------------

Private Function SetObjectAsBuffer(ByRef unverified_value, ByRef buffer_value) As Boolean
    
On Error GoTo errLabel
    If IsObject(unverified_value) Then
        Set buffer_value = unverified_value
        SetObjectAsBuffer = True
    Else
        buffer_value = unverified_value
        SetObjectAsBuffer = False
    End If
    Exit Function
    
errLabel:
    Err.Raise 10001, Err.Source & vbCrLf & "at Lambda.SetObjectAsBuffer()", Err.Description
End Function

Private Function IsOperator(operator_string) As Boolean
    Dim o
    
    IsOperator = True
    For Each o In Operators
        If Left(operator_string, Len(o)) = o Then Exit Function
    Next
    IsOperator = False
    
End Function

Private Function TakeOperator(operator_string) As String
    Dim o
    
    For Each o In Operators
        If Left(operator_string, Len(o)) = o Then TakeOperator = (o): Exit Function
    Next
    
End Function

Private Property Get Operators()
    Operators = Array(" Imp ", " Eqv ", " Xor ", " Or ", " And ", " Not ", _
                      " Is ", " Like ", "<=", ">=", ">", "<", "<>", "=", _
                      "&", "+", "-", " Mod ", "\", "*", "/", " ^ ")
End Property

Private Function AddTags(formula_string As String) As String
    Dim str As String
    
    str = formula_string
    str = AddTag(str, "#")
    str = AddTag(str, """")
    AddTags = str

End Function

Private Function AddTag(formula_string As String, by_tag_key As String) As String
    Dim l  As String, r As String, p As String, stck As New Collection, is_open As Boolean, ln As Long
    
    ln = Len(by_tag_key)
    r = formula_string
    Do While r <> ""
        Select Case Mid(r, 1, ln)
        Case by_tag_key
            If is_open Then
                If by_tag_key = """" Then l = AddTagAs(l, TAG_STRING_OPEN, TAG_STRING_CLOSE)
                If by_tag_key = "#" Then l = AddTagAs(l, TAG_DATE_OPEN, TAG_DATE_CLOSE)
                Call PopStack(stck, p)
                l = p & l
                r = Mid(r, ln + 1)
                is_open = False
            Else
                Call PushStack(stck, l)
                l = ""
                r = Mid(r, ln + 1)
                is_open = True
            End If
        End Select
        l = l & Mid(r, ln, 1)
        r = Mid(r, ln + 1)
    Loop
    Let AddTag = l

End Function


Private Function IsBoolean(ByVal str) As Boolean
    
    str = Trim(LCase(str))
    If str = "true" Or str = "false" Then IsBoolean = True Else IsBoolean = False
    
End Function


Private Function RemoveTags(unverfied_value, re_value)
    
    If IsObject(unverfied_value) Then
        Set re_value = unverfied_value
    ElseIf IsArray(unverfied_value) Then
        Let re_value = unverfied_value
    ElseIf VarType(unverfied_value) = vbBoolean Then
        re_value = unverfied_value
    ElseIf IsBoolean(unverfied_value) Then
        re_value = CBool(unverfied_value)
    ElseIf HasTagBy(unverfied_value, TAG_DATE_OPEN) Then
        re_value = DateValue(RemoveTagAs(unverfied_value, TAG_DATE_OPEN, TAG_DATE_CLOSE))
    ElseIf HasTagBy(unverfied_value, TAG_STRING_OPEN) Then
        re_value = RemoveTagAs(unverfied_value, TAG_STRING_OPEN, TAG_STRING_CLOSE)
    ElseIf IsNumeric(unverfied_value) Then
        re_value = val(unverfied_value)
    Else
        re_value = unverfied_value
    End If

End Function

Private Function HasTagBy(str, ta) As Boolean
    
    If Left(str, Len(ta)) = ta Then HasTagBy = True Else HasTagBy = False

End Function

Private Function AddTagAs(converting_string, tag_open, tag_close) As String
    
    If Left(converting_string, 1) = "<" And Right(converting_string, 2) = "/>" Then AddTagAs = converting_string Else AddTagAs = tag_open & converting_string & tag_close

End Function

Private Function RemoveTagAs(deconverting_string, tag_open, tag_close)
    
    If Left(deconverting_string, 1) = "<" And Right(deconverting_string, 2) = "/>" Then RemoveTagAs = Replace(Replace(deconverting_string, tag_open, ""), tag_close, "") Else RemoveTagAs = deconverting_string

End Function

Private Function GetTagSpanLengthWithStarted(str) As Long
    
    If IsStartedWithTags(str) = False Then
        GetTagSpanLengthWithStarted = 0
    Else
        GetTagSpanLengthWithStarted = InStr(str, "/>") + Len("/>") - 1
    End If

End Function

Private Function IsStartedWithTags(str) As Boolean
    
    IsStartedWithTags = False
    If Left(str, Len(TAG_STRING_OPEN)) = TAG_STRING_OPEN Then IsStartedWithTags = True
    If Left(str, Len(TAG_DATE_OPEN)) = TAG_DATE_OPEN Then IsStartedWithTags = True
        
End Function


' related arrays -------------------------------
Private Function ArrayCount(arr, Optional d As Long = 1) As Long
    
    ArrayCount = UBound(arr, d) - LBound(arr, d) + 1

End Function

Private Function IsMethodPropOrArrayString(monomical_string) As Boolean
    
    IsMethodPropOrArrayString = InStr(monomical_string, "Call ") > 0
    If IsMethodPropOrArrayString Then monomical_string = Replace(monomical_string, "Call ", "")
    
End Function

Private Function ExtructProcNameParamString(function_string, ByRef proc_name, ByRef param_string)
    Dim index_parenthes_open, l, r
    
    index_parenthes_open = InStr(function_string, "(")
    If index_parenthes_open < 1 Then
        proc_name = function_string
        param_string = ""
    Else
        proc_name = Left(function_string, index_parenthes_open - 1)
        Call SplitFirsrParenthese(Mid(function_string, Len(proc_name) + 1), l, r)
        param_string = Mid(l, 2, Len(l) - 2)
    End If

End Function

Private Function ExtructProcParamString(function_string) As String
    Dim index_parenthes_open
    
    index_parenthes_open = InStr(function_string, "(")
    If index_parenthes_open < 1 Then ExtructProcParamString = function_string: Exit Function
    ExtructProcParamString = Left(function_string, index_parenthes_open - 1)

End Function

Private Function HasVariable(formula_string As String) As Boolean
    Dim v, f As Boolean
    
    For Each v In vars_
       If InStr(formula_string, v(1)) > 0 Then HasVariable = True: Exit Function
    Next

End Function

Private Function CollectionToArray(col As Collection)
    Dim arr, i
    
    If col.Count = 1 Then
        arr = col(1)
    Else
        
        ReDim arr(0 To col.Count - 1)
        For i = 0 To UBound(arr)
            Call SetObjectAsBuffer(col(i + 1), arr(i))
        Next i
    End If
    Let CollectionToArray = arr
End Function

Private Function GetInnerStringsClosedBy(str As String, closed_by As String) As String
    Dim l As Long
    
    Let l = Len(closed_by) + 1
    Let GetInnerStringsClosedBy = Mid(str, l, Len(str) - l)
    
End Function

Private Function PushStack(pushed_stack As Collection, var As Variant)

    pushed_stack.Add var

End Function

Private Function PopStack(poped_stack As Collection, var As Variant)

    If poped_stack.Count > 0 Then
        SetObjectAsBuffer poped_stack(poped_stack.Count), var
        poped_stack.Remove poped_stack.Count
    End If

End Function

Private Function IsNullOrEmptyOrNothing(unverified_value) As Boolean
    
    If IsObject(unverified_value) Then
        Let IsNullOrEmptyOrNothing = (unverified_value Is Nothing)
    Else
        Let IsNullOrEmptyOrNothing = (IsNull(unverified_value) Or IsEmpty(unverified_value))
    End If

End Function

