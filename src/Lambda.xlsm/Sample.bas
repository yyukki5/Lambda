Attribute VB_Name = "Sample"
Option Explicit

Sub SampleCode()
    Dim res
    res = Lambda(1, "x=>x ^ x + 1").Evaluate
    Debug.Print res
    
End Sub



