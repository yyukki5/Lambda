Attribute VB_Name = "Sample"
Option Explicit

Sub SampleCode()
    Dim res
    res = Lambda(1, "x=>x ^ x + 1").Evaluate
    Debug.Print "The result is... " & res
    
    Dim lam As New Lambda, v
    v = 3
    DebugPrint lam(v, "x=>x + 3")
End Sub

Private Function DebugPrint(lam As Lambda)
    Debug.Print "This print is from DebugPrint... " & lam.Evaluate
End Function

