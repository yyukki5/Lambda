Attribute VB_Name = "Sample"
Option Explicit

Sub SampleCode()
    Dim res
    res = Lambda(1, "x=>x ^ x + 1").Evaluate
    Debug.Print "The result is... " & res
    
    res = Lambda(Array(1, 2), "(x,y) => x * y + 1").Evaluate
    Debug.Print "The result is... " & res
    
    Dim lam As New Lambda
    Call DebugPrint("x=>x + 3")
    Call DebugPrint("x=>x * x + 3")
End Sub

Private Function DebugPrint(lam As String)
    Debug.Print "(lambda) This print is from DebugPrint... " & lam & " : " & Lambda(4, lam).Evaluate
End Function

