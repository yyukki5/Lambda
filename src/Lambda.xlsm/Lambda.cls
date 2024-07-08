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
'  - multi arguments
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

Private Enum lmParseCase
    lmNoFound
    lmOperator
    lmOpenParenthese
    lmCloseParenthese
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
    Dim evaluated_value, polynominal_collection As Collection

'On Error GoTo errEvaluate
    Call SetObjectAsBuffer(ParsePolynominal(lambdaString_), evaluated_value)
    Call RemoveTags(evaluated_value, Evaluate)
    Exit Function
    
errEvaluate:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.Evaluate()", Err.Description
End Function



'Private ---------------------------------------------
Private Function ParsePolynominal(polynominal_string As String) As Variant
    Dim polynominal_collection As Collection, polynominal_collection_re As New Collection, p
    
    Set polynominal_collection = SplitPolynominal(polynominal_string)
    
    For Each p In polynominal_collection
        Select Case p(lmIsOpe)
        Case lmPoly
            Call SetObjectAsBuffer(ParsePolynominal((p(lmValue))), p(lmValue))
        Case lmMono
            Call SetObjectAsBuffer(ConvertMonominalStringToValue2((p(lmValue))), p(lmValue))
        End Select
        Call polynominal_collection_re.Add(p)
    Next
    
    Call EvaluetePolynominalCollection(polynominal_collection_re, ParsePolynominal)
End Function

Private Function ConvertMonominalStringToValue2(monominal_string As String) As Variant
    Dim monominal_collection As Collection, tmp, m, p
    
    Set monominal_collection = SplitMonominalStringByDot(monominal_string)
    For Each m In monominal_collection
        Call SetObjectAsBuffer(ConvertMonominalObjectToValue(m, p), p)
    Next
    Call SetObjectAsBuffer(p, ConvertMonominalStringToValue2)
    
End Function

Private Function ConvertMonominalObjectToValue(object_string, parent_object) As Variant
    Dim formula_string As String, inner_string As String, inner_collection As Collection, inner_collection_re As New Collection, ic
    
    Call ExtructProcNameParamString(object_string, formula_string, inner_string)
    Set inner_collection = SplitByComma(inner_string)
    
    For Each ic In inner_collection
          Call inner_collection_re.Add(ParsePolynominal((ic)))
    Next ic
    Set inner_collection = inner_collection_re
    
    Call SetObjectAsBuffer(EvaluateMonominalObject(formula_string, inner_collection, parent_object), _
        ConvertMonominalObjectToValue)

End Function

Private Function IsNullOrNothing(unverified_value) As Boolean
    
    If IsObject(unverified_value) Then
        Let IsNullOrNothing = (unverified_value Is Nothing)
    Else
        Let IsNullOrNothing = (IsNull(unverified_value) Or IsEmpty(unverified_value))
    End If

End Function

Private Function EvaluateMonominalObject(formula_string As String, inner_collection As Collection, parent_object) As Variant
    Dim v, tmp
    
    formula_string = Trim(formula_string)
    If IsNullOrNothing(parent_object) Then
        If HasVariable(formula_string) Then
            Call SetObjectAsBuffer(GetVarByVarName(formula_string), tmp)
            If IsArray(tmp) And inner_collection.Count > 0 Then _
                Call SetObjectAsBuffer(GetArrayWithArgument(tmp, inner_collection), tmp)
        Else
            If IsMethodPropOrArrayString(formula_string) Then
                Call SetObjectAsBuffer(RunMethod(formula_string, inner_collection), tmp)
            Else
                tmp = formula_string
            End If
        End If
    Else
        Call SetObjectAsBuffer(GetChildVar(formula_string, inner_collection, parent_object), tmp)
    End If

    Call AddTag(tmp, tmp)
    Call SetObjectAsBuffer(tmp, EvaluateMonominalObject)

'errFunction:
'    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.TryConvertMonomialToValue()", Err.Description
End Function

Private Function GetChildVar(formula_string As String, inner_collection As Collection, parent_object)
    Dim arguments, err_num, err_des, tmp
    If inner_collection.Count > 0 Then
    On Error Resume Next
        Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet), tmp)
        Err.Clear
        If IsArray(tmp) Then
            Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet), tmp)
            Call SetObjectAsBuffer(GetArrayWithArgument(tmp, inner_collection), tmp)
        Else
            arguments = CollectionToArray(inner_collection)
            Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet, arguments), tmp)
            If Err.Number = 450 Then
                Err.Clear
                Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbMethod, arguments), tmp)
            End If
            If Err.Number <> 0 Then err_num = Err.Number: err_des = Err.Description
            On Error GoTo 0:    If err_num <> 0 Then Call Err.Raise(err_num, "GetChildVar()", err_des)
        End If
    Else
    On Error Resume Next
        Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbGet), tmp)
        If Err.Number = 450 Then
            Err.Clear
            Call SetObjectAsBuffer(CallByName(parent_object, formula_string, VbMethod), tmp)
        End If
        If Err.Number <> 0 Then err_num = Err.Number: err_des = Err.Description
        On Error GoTo 0:   If err_num <> 0 Then Call Err.Raise(err_num, "GetChildVar()", err_des)
    End If
    
    Call SetObjectAsBuffer(tmp, GetChildVar)
End Function

Private Function GetVarByVarName(formula_string)
    Dim v
    For Each v In vars_
        If formula_string = v(lmVarTypeName) Then Call SetObjectAsBuffer(v(lmVarTypeVar), GetVarByVarName): Exit Function
    Next
    Call Err.Raise(11000, "GetVarByVarName()", "not found variable")
End Function

Private Function RunMethod(method_name As String, ic As Collection)
    Dim tmp
    Select Case ic.Count
    Case 0:   Call SetObjectAsBuffer(Application.Run(method_name), tmp)
    Case 1:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1)), tmp)
    Case 2:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2)), tmp)
    Case 3:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3)), tmp)
    Case 4:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3), ic(4)), tmp)
    Case 5:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3), ic(4), ic(5)), tmp)
    Case 6:   Call SetObjectAsBuffer(Application.Run(method_name, ic(1), ic(2), ic(3), ic(4), ic(5), ic(6)), tmp)
    Case Else
        Err.Raise 11000, "RunMethod"
    End Select
    
    Call SetObjectAsBuffer(tmp, RunMethod)
End Function

Private Function GetArrayWithArgument(arr, ic As Collection)
    Dim tmp
    Select Case ic.Count
    Case 1:   Call SetObjectAsBuffer(arr(ic(1)), tmp)
    Case 2:   Call SetObjectAsBuffer(arr(ic(1), ic(2)), tmp)
    Case 3:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3)), tmp)
    Case 4:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3), ic(4)), tmp)
    Case 5:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3), ic(4), ic(5)), tmp)
    Case 6:   Call SetObjectAsBuffer(arr(ic(1), ic(2), ic(3), ic(4), ic(5), ic(6)), tmp)
    Case Else
        Err.Raise 11000, "RunMethod"
    End Select
    
    Call SetObjectAsBuffer(tmp, GetArrayWithArgument)
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
        
        Let left_string = left_string & Left(right_string, 1)
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
        Case lmPoly:        Call polynoimal_collection.Add(Array(lmPoly, Mid(left_string, 2, Len(left_string) - 2)))
        End Select
    Loop
    Set SplitPolynominal = polynoimal_collection

End Function

Private Function SplitPolynoinalString(str As String, left_string As String, right_string As String, ope As String) As lmPolynominalParseCase
    
    If IsOperator(str) Then
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










Private Function ConvertInnerParenthesStringsToCollection(inner_string As String) As Collection
    Dim inner_strings As Collection, inner_collection As New Collection
    Dim polynominal_string, polynominal_collection As Collection
    Dim reval
        
    Set inner_strings = SplitByComma(inner_string)
    For Each polynominal_string In inner_strings
        Set polynominal_collection = ParseString((polynominal_string))
        Call EvaluetePolynominalCollection(polynominal_collection, reval)
        Call inner_collection.Add(reval)
    Next
    Set ConvertInnerParenthesStringsToCollection = inner_collection
    
End Function

Private Function SplitByOperatorOr1Char(ByVal str As String, left_str As String, right_str As String, ope) As lmParseCase
    Dim start_index As Long, parenthese_or_other As String
    
    If IsOperator(str) Then
        SplitByOperator str, ope, right_str
        SplitByOperatorOr1Char = lmOperator
    Else
        start_index = GetTagSpanLengthWithStarted(str)
        parenthese_or_other = Mid(str, start_index + 1, 1)
        left_str = Left(str, start_index + 1)
        right_str = Mid(str, start_index + 2)
        ope = ""
        
        Select Case parenthese_or_other
            Case "(": SplitByOperatorOr1Char = lmOpenParenthese
            Case ")": SplitByOperatorOr1Char = lmCloseParenthese
            Case Else: SplitByOperatorOr1Char = lmNoFound
        End Select
    End If
    
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

Private Function ConvertToPolynominalCollectionFrom(polynominal_string As String) As Collection

End Function

Private Function SplitByOperator(str, ope, right_str)
    ope = TakeOperator(str)
    right_str = Mid(str, Len(ope) + 1)
End Function

Private Function ConvertToMonominalValueFrom(monminal_string As String) As Variant
    Dim reval
    TryConvertMonomialToValue monminal_string, ConvertToMonominalValueFrom
    
End Function

Private Function EvaluatePreParentheses(inner_collection As Collection, pre, reval)
        
    If inner_collection.Count = 0 Then:    reval = Null: Exit Function
    Call ConvertMonominalStringToValue((pre), Null, inner_collection, reval)
    
        
End Function

Private Function EvaluetePolynominalCollection(pc As Collection, reval)
    
    If pc.Count = 0 Then
        Exit Function
    ElseIf pc.Count = 1 Then
        SetObjectAsBuffer pc(1)(1), reval: Exit Function
    Else
        reval = RunEvaluatePolynominalCollectionRec(pc)
    End If
    
End Function

Private Function ConvertMonominalStringToValue(monominal_string As String, parent_val As Variant, args As Collection, reval As Variant)
    Dim re As Variant
    
    If Trim(monominal_string) = "" Then
        If IsEmpty(parent_val) Then
            SetObjectAsEmpty reval:   Exit Function
        Else
            SetObjectAsBuffer parent_val, reval
            Exit Function
        End If
    End If
    
    If args.Count = 0 Then
        If Left(monominal_string, 1) = "." Then SetObjectAsBuffer CallByName(parent_val, Trim(Mid(monominal_string, 2)), VbGet), reval: Exit Function
        TryConvertMonomialToValue monominal_string, reval
    Else
        ' todo improve to apply multi arguments
        Call TryConvertMonomialToValue(monominal_string & args(1) & ")", reval)
    
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
        If c(lmIsOpe) = lmOpe And c(lmValue) = ope And f = False Then f = True: GoTo nextloop
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

Private Function PushStack(pushed_stack As Collection, var As Variant)
    pushed_stack.Add var
End Function
Private Function PopStack(poped_stack As Collection, var As Variant)
    If poped_stack.Count > 0 Then
        SetObjectAsBuffer poped_stack(poped_stack.Count), var
        poped_stack.Remove poped_stack.Count
    End If
End Function































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
    Dim current_str As String, char As String, i As Long, calculated_value
    Dim formula_stack As Collection: Set formula_stack = New Collection

    For i = 1 To Len(formula_string)
        char = Mid(formula_string, i, 1)

        If char = "(" Then
            If current_str <> "" Then formula_stack.Add current_str
            current_str = ""
    
        ElseIf char = ")" Then
            ' after close parenthese ----------
            calculated_value = ConvertPolynomialStringToVariant(current_str)
            
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



' example) "x.abc.def + x.abc.efg + 1"  ->  "3 + 5 + 1" -> 9
Private Function ConvertPolynomialStringToVariant(formula_str As String) As Variant
    Dim calculated_value, calculated_string
    Dim monominal_string As String, buf_val, v, temp_polynominal_string As String, formula_str_re, fcol As New Collection
    Dim polynominal_collection As Collection
    
    On Error GoTo errFor
    Set polynominal_collection = SplitPolynomoinalStringByOperator(formula_str)
    
    Dim p
    For Each p In polynominal_collection
        If p(0) = False Then Call TryConvertMonomialToValue((p(1)), p(1))
    Next
    
    Call EvaluatePolynominalCollection(polynominal_collection, reval)
    
'    calculated_value = RunEvaluate(calculated_string)
    
    If IsError(calculated_value) Then Err.Raise 9006, "Lambda.ConvertPolynomialStringToVariant()", "Unsupported lambda string. can not evaluate formula"
    
    ConvertPolynomialStringToVariant = calculated_value
End Function



' example) "x.abc" -> x.abc,  "x.abc.def" -> 3,   "x.abc + x.abc.def" -> x.abc + 3 (error)
Private Function TryConvertPolynominalToValue(formula_str As String, ByRef return_value) As Boolean

    If IsMonomical(formula_str) = False Then
        ' has operator -> polynominal
        return_value = ConvertPolynomialStringToVariant(formula_str)
        TryConvertPolynominalToValue = False
    Else
        ' nothing operator ->  monominal
        TryConvertPolynominalToValue = TryConvertMonomialToValue(formula_str, return_value)
    End If
    
End Function

' example) "x.abc.def + x.abc.efg + 1"  ->  "3 + 5 + 1"
Private Function ConvertToPolynomialWithoutObject(formula_str As String) As String
    Dim monominal_string As String, buf_val, v, temp_polynominal_string As String, formula_str_re, fcol As New Collection
    Dim polynominalColl As Collection
    
    On Error GoTo errFor
    Set polynominalColl = SplitPolynomoinalStringByOperator(formula_str)
    
    Dim p
    For Each p In polynominalColl
        If p(0) = False Then Call TryConvertMonomialToValue((p(1)), p(1))
    Next
    
    
    ConvertToPolynomialWithoutObject = formula_str_re
    Exit Function
errFor:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.ConvertToPolynomialWithoutObject()", Err.Description
End Function

Private Function SplitPolynomoinalStringByOperator(formula_str As String) As Collection
    Dim monominal_string As String, ope As String, temp_polynominal_string As String, fcol As New Collection
    
    temp_polynominal_string = formula_str
    Do While Len(temp_polynominal_string) > 1
        
        Call GetMonominalAnsOperatorStringFromPolynomial(temp_polynominal_string, monominal_string, ope)
        
        fcol.Add Array(False, monominal_string)
        If ope <> "" Then fcol.Add Array(True, ope)
    Loop
    
    Set SplitPolynomoinalStringByOperator = fcol
End Function


'1.2.1 extruct string to operator string. ex) "abc.def + 2" -> "abc.def "
Private Function GetMonominalStringFromPolynomial(polynomial_string, ByRef next_polynominal As String) As String
    Dim start_index, last_index, term_string As String
    
'    start_index = InStrVariable(polynomial_string)
    start_index = 1
    last_index = IIf(InStrOperator(polynomial_string, start_index) = 0, Len(polynomial_string), InStrOperator(polynomial_string, start_index) - 1)
    term_string = Mid(polynomial_string, start_index, last_index - start_index + 1)
    
    GetMonominalStringFromPolynomial = term_string
    next_polynominal = Mid(polynomial_string, InStrOperator(polynomial_string, start_index) + LenOperator(polynomial_string) + 1)
End Function

Private Function GetMonominalAnsOperatorStringFromPolynomial(ByRef polynomial_string, ByRef monominal_string As String, ByRef operator_string As String)
    Dim start_index, last_index, right_string As String
    
    start_index = 1
    last_index = IIf(InStrOperator(polynomial_string, start_index) = 0, Len(polynomial_string), InStrOperator(polynomial_string, start_index) - 1)
    monominal_string = Mid(polynomial_string, start_index, last_index - start_index + 1)
    
    right_string = Mid(polynomial_string, last_index + 1)
    operator_string = Mid(right_string, 1, LenOperator(right_string))
    polynomial_string = Mid(right_string, Len(operator_string) + 1)
End Function


'1.2.2 example) "x.abc.def" -> 1 ,  "x" -> 1, "1" -> 1
Private Function TryConvertMonomialToValue(monominal_string As String, ByRef return_value) As Boolean
    Dim splited_by_dots() As String, splited_by_dot, i, eval_var, var_str As String, v, re As Variant
    
    monominal_string = Replace(monominal_string, " ", "")
    If monominal_string = "" Then SetObjectAsBuffer re, return_value: Exit Function
    
On Error GoTo errFunction
    If HasVariable(monominal_string) Then
        For Each v In vars_
            If HasChildString(monominal_string) Then
                ' "x.abc.def" -> 1
                splited_by_dots = Split(monominal_string, ".")
                SetObjectAsBuffer v(0), return_value
                For i = 1 To UBound(splited_by_dots)
                    Call SetCallByNameValue(return_value, (splited_by_dots(i)), return_value)
                Next
            Else
                ' "x" -> 1 , "x(1)" -> 1 , x() -> 1
                Call ConvertFromVariableStringToValue(v(0), monominal_string, return_value)
            End If
        Next
    Else
        Call ConvertFromStringToValue(monominal_string, return_value)
    End If
    
    AddTag return_value, return_value
    If IsObject(return_value) Then TryConvertMonomialToValue = True Else TryConvertMonomialToValue = False
    Exit Function
errFunction:
    Err.Raise Err.Number, Err.Source & vbCrLf & "at Lambda.TryConvertMonomialToValue()", Err.Description
End Function


Private Function ConvertFromStringToValue(monominal_string As String, ByRef return_value)
    If IsMethodPropOrArrayString(monominal_string) Then
        Err.Raise 9004, "Lambda.ConvertFromStringToValue()", "Lambda string has error. unsupported string.: " & monominal_string
    Else
        SetObjectAsBuffer monominal_string, return_value
    End If
End Function

Private Function ConvertFromVariableStringToValue(var0, monominal_string As String, ByRef return_value)
    Dim val
    If IsMethodPropOrArrayString(monominal_string) And IsArray(var0) Then
        ' "x(1)" -> 1
        Call TryGetArrayValue(var0, GetParametersByString(monominal_string), return_value)
        
    ElseIf IsMethodPropOrArrayString(monominal_string) And IsArray(var0) = False Then
        ' todo write more details
        Err.Raise 9004, "Lambda.ConvertFromVariableStringToValue()", "Lambda string has error. cannot evaluate.: " & monominal_string
    Else
        ' x, 123
        SetObjectAsBuffer var0, return_value
    End If

'    SetObjectAsBuffer val, return_value
End Function

Private Function SetCallByNameValue(called_object, called_proc As String, ByRef return_value) As Boolean
    Dim re, args As Variant, called_proc_name As String
        
    args = GetParametersByString(ExtructProcParamString(called_proc))
    called_proc_name = GetProcName(called_proc)
    
    If HasArgumentString(called_proc) Then
        ' property or method  retured value is array
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
    
    Else
        ' property or method
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
    End If
    
End Function


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




















' ---- element functions ---------------------------------------------

Private Function SetObjectAsBuffer(ByRef unverified_value, ByRef buffer_value) As Boolean
    
    If IsObject(unverified_value) Then
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
        i = i + GetTagSpanLengthWithStarted(str)
        str = Mid(string_has_operator, i)
        If Left(str, Len(o)) = o Then InStrOperatorBy = i: Exit Function
    Next i
    InStrOperatorBy = 0
    
End Function

Private Function InStrOperator(string_has_operator, start_index) As Long
    Dim i As Long, str As String
    
    str = Mid(string_has_operator, start_index)
    For i = start_index To Len(string_has_operator)
        i = i + GetTagSpanLengthWithStarted(str)
        str = Mid(string_has_operator, i)
        If IsOperator(str) Then InStrOperator = i: Exit Function
    Next i
    InStrOperator = 0
    
End Function

Private Function IsOperator(operator_string) As Boolean
    Dim o
    
    IsOperator = True
    For Each o In Operators
        If Left(operator_string, Len(o)) = o Then Exit Function
    Next
    IsOperator = False
    
End Function

Private Function LenOperator(operator_string) As Long
    Dim o
    
    For Each o In Operators
        If Left(operator_string, Len(o)) = o Then LenOperator = Len(o): Exit Function
    Next
    
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
    
    If HasStartedWithTags(str) = False Then
        GetTagSpanLengthWithStarted = 0
    Else
        GetTagSpanLengthWithStarted = InStr(str, "/>") + Len("/>") - 1
    End If

End Function

Private Function HasStartedWithTags(str) As Boolean
    
    HasStartedWithTags = False
    If Left(str, Len(TAG_STRING_OPEN)) = TAG_STRING_OPEN Then HasStartedWithTags = True
    If Left(str, Len(TAG_DATE_OPEN)) = TAG_DATE_OPEN Then HasStartedWithTags = True
        
End Function


' related arrays -------------------------------
Private Function TryGetArrayValueByString(arr, array_sting, reval) As Boolean
    Dim pstr As String, parr
    
    If HasArgumentString(array_sting) Then
        pstr = ExtructArrayParametersString(array_sting)
        TryGetArrayValueByString = TryGetArrayValueByParamstersString(arr, pstr, reval)
    Else
        reval = arr
        TryGetArrayValueByString = True
    End If

End Function
Private Function TryGetArrayValueByParamstersString(arr, parameter_sting, reval) As Boolean
        Dim pstr As String, parr
        
        parr = GetParametersByString(parameter_sting)
        TryGetArrayValueByParamstersString = TryGetArrayValue(arr, parr, reval)

End Function

Private Function ExtructArrayParametersString(array_sting, Optional obj_name As String = "") As String
    
    If InStr(array_sting, "(") > 0 Then
        ExtructArrayParametersString = Mid(array_sting, Len(obj_name) + 1)
    Else
        ExtructArrayParametersString = ""
    End If

End Function
Private Function GetParametersByString(parameters_sting)
    
    GetParametersByString = Split(parameters_sting, ",")
    If UBound(GetParametersByString) = 0 Then GetParametersByString = parameters_sting

End Function
Private Function TryGetArrayValue(arr, p, reval) As Boolean
    Dim rnk As Long: rnk = UBound(p) - LBound(p) + 1
    
On Error GoTo errArray
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

Private Function HasArgumentString(monominal_string) As Boolean
    Dim index_parenthes_open
    
    index_parenthes_open = InStr(monominal_string, "(")
    HasArgumentString = index_parenthes_open > 0

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

Private Function IsVariableString(formula_string As String) As Boolean
    Dim v, f As Boolean
    
    For Each v In vars_
       If formula_string = v(1) Then IsVariableString = True: Exit Function
    Next

End Function

Private Function HasVariableBy(formula_string As String, var_string As String) As Boolean
    
    HasVariableBy = InStr(formula_string, var_string) > 0

End Function

Private Function InStrVariable(formula_string) As Long
    Dim i As Long, j As Long, str As String
    
    For j = 1 To Len(formula_string)
        str = Mid(formula_string, j)
        For i = 1 To Len(formula_string)
            i = i + GetTagSpanLengthWithStarted(str)
            If IsVariableString(Mid(formula_string, j, i)) Then InStrVariable = j: Exit Function
        Next i
    Next j
    InStrVariable = 0

End Function

Private Function HasChildString(monomical_string) As Boolean
    
    HasChildString = (ArrayCount(Split(monomical_string, ".")) <> 1)

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

