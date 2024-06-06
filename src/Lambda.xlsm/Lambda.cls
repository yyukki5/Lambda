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
' Version   : 0.2.0
' ---
' try to simply calculate by not using Evaluate().
' ----------------------------------------------------

Public Function Evaluate(val, lambdaString As String)
Attribute Evaluate.VB_UserMemId = 0
    Dim varstr As String, formulastr As String, parsedString As String, calculatedValue
On Error GoTo errEvaluate
    Call SetLambdaValueFormula(lambdaString, varstr, formulastr)
    parsedString = ParseParentheses(val, varstr, formulastr)
    If CalcInnerParentheses(val, varstr, parsedString, calculatedValue) = False Then Set Evaluate = calculatedValue: Exit Function
    
    Evaluate = RunEvaluate(calculatedValue)
    Exit Function
    
errEvaluate:
    Err.Raise Err.Number, Err.Source & vbCrLf & "Lambda.Evaluate()", Err.Description
End Function


'Private ---------------------------------------------
Private Function SetLambdaValueFormula(str As String, varstr As String, formulastr As String)
    str = Replace(str, " ", "")
    
    If InStr(str, "=>") = 0 Then Err.Raise 9001, "Lambda.SetLambdaValueFormula()", "Lambda string has error. need ""=>"""
    varstr = Mid(str, 1, InStr(str, "=>") - 1)
    formulastr = Mid(str, InStr(str, "=>") + 2)
    
    If Len(varstr) = 0 Then Err.Raise 9002, "Lambda.SetLambdaValueFormula()", "Lambda string has error."
    If Len(formulastr) = 0 Then Err.Raise 9002, "Lambda.SetLambdaValueFormula()", "Lambda string has error."
End Function

Private Function ParseParentheses(var, varstr As String, formulastr As String) As String
    Dim stack As Collection, currentString As String, char As String, i As Long, calculatedValue, calculatedString

    Set stack = New Collection
    currentString = ""
    calculatedValue = ""
    calculatedString = ""

    For i = 1 To Len(formulastr)
        char = Mid(formulastr, i, 1)

        If char = "(" Then
            If currentString <> "" Then stack.Add currentString
            currentString = ""
        ElseIf char = ")" Then
            
            If InStr(currentString, varstr) > 0 Then
                If CalcInnerParentheses(var, varstr, currentString, calculatedString) = False Then _
                    Err.Raise 9001, "Lambda.ParseParentheses()", "Unsupport error: can not evaluate object "  ' todo maybe able to calculate
                calculatedValue = RunEvaluate(calculatedString)
                If IsError(calculatedValue) Then Err.Raise 9006, "Lambda.ParseParentheses()", "Unsupported lambda string. can not evaluate formula"
            Else
                calculatedValue = RunEvaluate(currentString)
            End If
            ' after close bracket ----------
            If stack.Count > 0 Then
                currentString = stack.Item(stack.Count) & "(" & calculatedValue & ")"
                stack.Remove stack.Count
                
                If Mid(formulastr, i + 1, 1) <> "." Then Call CalcInnerParentheses(var, varstr, currentString, currentString)
            Else
                currentString = ""
            End If
            ' -----------------------------
        Else
            currentString = currentString & char
        End If
    Next i
    ParseParentheses = currentString
End Function

Private Function CalcInnerParentheses(val, varstr As String, formulastr As String, returnValue)
    Dim sta, lst, termString As String, reval
    Do While InStr(formulastr, varstr) > 0
    
        sta = InStr(formulastr, varstr)
        lst = IIf(InStrOperator(formulastr, sta) = 0, Len(formulastr), InStrOperator(formulastr, sta) - 1)
        termString = Mid(formulastr, sta, lst - sta + 1)
        
        Call SetCalculatedTermValue(val, termString, reval)
        If IsObject(reval) Then Set returnValue = reval: CalcInnerParentheses = False: Exit Function '
        If VarType(reval) > vbArray Then Err.Raise 9001, "Lambda.CalcInnerParentheses()", "Unsupport array for evaluate"
        formulastr = Replace(formulastr, termString, reval)
    Loop
    returnValue = formulastr
    CalcInnerParentheses = True
End Function

Private Function SetCalculatedTermValue(val, termstr As String, ByRef reval) As Boolean
    Dim sp, i, indBrktOpen As Long
    sp = Split(termstr, ".")
    
    If UBound(sp) = 0 Then
        If InStrOperator(CStr(termstr), 1) > 0 Then Err.Raise 9004, "Lambda.SetCalculatedTermValue()", "Lambda string has error."
        If IsObject(val) Then Set reval = val Else reval = val
    Else
        Set reval = val
        For i = 1 To UBound(sp)
            If sp(i) = "" Then Err.Raise 9004, "Lambda.SetCalculatedTermValue()", "Lambda string has error."
            
            indBrktOpen = InStr(sp(i), "(")
            If indBrktOpen > 0 Then
                Call SetCallByNameValue(reval, Left(sp(i), indBrktOpen - 1), reval, Mid(sp(i), indBrktOpen + 1, InStr(sp(i), ")") - indBrktOpen - 1))
            Else
                Call SetCallByNameValue(reval, CStr(sp(i)), reval)
            End If
        Next i
    End If
    
    If IsObject(reval) Then SetCalculatedTermValue = True Else SetCalculatedTermValue = False
End Function

Private Function InStrOperator(str, sta) As Long
    Dim i As Long
    For i = 0 To Len(str) - 1
        If IsOperator(Mid(str, sta + i)) Then InStrOperator = sta + i: Exit Function
    Next i
    InStrOperator = 0
End Function

Private Function IsOperator(str) As Boolean
    IsOperator = True
    If Left(str, 1) = "<" Then Exit Function
    If Left(str, 2) = "<=" Then Exit Function
    If Left(str, 1) = ">" Then Exit Function
    If Left(str, 2) = ">=" Then Exit Function
    If Left(str, 1) = "=" Then Exit Function
    If Left(str, 1) = "+" Then Exit Function
    If Left(str, 1) = "-" Then Exit Function
    If Left(str, 1) = "*" Then Exit Function
    If Left(str, 1) = "/" Then Exit Function
    If Left(str, 1) = "^" Then Exit Function
    If Left(str, 1) = "&" Then Exit Function
    IsOperator = False
End Function

Private Function SetCallByNameValue(cls, propName As String, ByRef reval, Optional args As Variant) As Boolean
    If IsMissing(args) Then
        On Error GoTo errGetWithoutArg
        Call SetObjBuf(CallByName(cls, propName, VbGet), reval)
        SetCallByNameValue = IsObject(reval)
        Exit Function
errGetWithoutArg:
        If Err.Number = 450 Then
            Call SetObjBuf(CallByName(cls, propName, VbMethod), reval)
            SetCallByNameValue = IsObject(reval)
        ElseIf Err.Number = 438 Then
            Err.Raise 9001, "Lambda.SetCallByNameValue()", "Not implemented property: " & TypeName(cls) & "." & propName
        Else
            Err.Raise Err.Number, Err.Source, Err.Description
        End If
    Else
        On Error GoTo errGetWitArg
        Call SetObjBuf(CallByName(cls, propName, VbGet, args), reval)
        SetCallByNameValue = IsObject(reval)
        Exit Function
errGetWitArg:
        If Err.Number = 450 Then
            Call SetObjBuf(CallByName(cls, propName, VbMethod, args), reval)
            SetCallByNameValue = IsObject(reval)
        ElseIf Err.Number = 438 Then
            Err.Raise 9001, "Lambda.SetCallByNameValue()", "Not implemented property: " & TypeName(cls) & "." & propName
        Else
            Err.Raise Err.Number, Err.Source, Err.Description
        End If
    End If
    Exit Function
End Function

Private Function SetObjBuf(ByRef val, ByRef reval)
    Dim isObj As Boolean
    isObj = IsObject(val)
    If isObj Then Set reval = val Else reval = val
End Function

Private Function RunEvaluate(nonParenthesesFormulaStr) As Variant
    Dim res, str, strFixedCaret
    strFixedCaret = Replace(nonParenthesesFormulaStr, "^", " ^ ")
    str = strFixedCaret
    res = SplitByOperator(str)
    RunEvaluate = res
End Function

Private Function SplitByOperator(str)
    Dim c, i As Long, ope, o, arrOpeLfRg(0 To 2)
    
On Error GoTo errSplitByOperator
    ' note: element arrangement in array equal calaculated order
    ope = Array(" Imp ", " Eqv ", " Xor ", " Or ", " And ", " Not ", _
                " Is ", " Like ", "<=", ">=", ">", "<", "<>", "=", _
                "&", "+", "-", " Mod ", "\", "*", "/", " ^ ")
    
    For Each o In ope
        For i = 1 To Len(str)
            If o = Mid(str, i, 1) Or o = Mid(str, i, 2) Or o = Mid(str, i, 3) Or o = Mid(str, i, 4) Or o = Mid(str, i, 5) Or o = Mid(str, i, 6) Then
                arrOpeLfRg(0) = o
                arrOpeLfRg(1) = Left(str, i - 1)
                arrOpeLfRg(2) = Mid(str, i + Len(o))
                
                SplitByOperator = Calc(arrOpeLfRg(0), SplitByOperator(arrOpeLfRg(1)), SplitByOperator(arrOpeLfRg(2)))
                Exit Function
            End If
        Next i
    Next
    If IsNumeric(str) Then SplitByOperator = val(str) Else SplitByOperator = str
    Exit Function
    
errSplitByOperator:
   Err.Raise 9001, Err.Number, Err.Description
    
End Function

Private Function Calc(ope, lf, rg)
    If IsNumeric(lf) Then lf = val(lf)
    If IsNumeric(rg) Then rg = val(rg)

On Error GoTo errCalc
    Select Case ope
        Case "<=": Calc = lf <= rg
        Case ">=": Calc = lf >= rg
        Case ">": Calc = lf > rg
        Case "<": Calc = lf < rg
        Case "<>": Calc = lf <> rg
        Case "=": Calc = lf = rg
        Case "&": Calc = lf & rg
        Case "+": Calc = lf + rg
        Case "-": Calc = lf - rg
        Case "*": Calc = lf * rg
        Case "/": Calc = lf / rg
        Case "\": Calc = lf \ rg
        Case " ^ ": Calc = lf ^ rg
        Case " Mod ": Calc = lf Mod rg
        Case " Imp ": Calc = lf Imp rg
        Case " Eqv ": Calc = lf Eqv rg
        Case " Xor ": Calc = lf Xor rg
        Case " Or ": Calc = lf Or rg
        Case " And ": Calc = lf And rg
        Case " Not ": Calc = Not lf
        Case " Like ": Calc = lf Like rg
        Case " Is ": Calc = lf Is rg
    End Select
    Exit Function
errCalc:
    Err.Raise 9001, "Lambda.Calc()", "formula string has error : " & lf & " " & ope & " " & rg
End Function
