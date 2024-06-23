VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Class1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private abc_
Private def_ As Class2

Property Get abc()
    abc = abc_
End Property
Property Get def() As Class2
    Set def = def_
End Property
Property Get parg(arg)
    parg = arg
End Property
Property Get ReCls2(arg) As Class2
    Dim cls2 As New Class2
    Set ReCls2 = cls2.Init(arg)
End Property
Property Get IsCls2(cls2 As Class2)
    IsCls2 = cls2.def
End Property
Property Get TheArray()
    TheArray = Array(1, 2, 3)
End Property
Property Get TheArray2()
    Dim arr2(1 To 2, 1 To 5)
    Dim i, j
    For i = LBound(arr2, 1) To UBound(arr2, 1)
        For j = LBound(arr2, 2) To UBound(arr2, 2)
            arr2(i, j) = i * j
        Next j
    Next i
    TheArray2 = arr2
End Property


Function Init(a) As Class1
    abc_ = a
    Set def_ = New Class2
    def_.Init (a + 1)
    Set Init = Me
End Function

Function Equals(cls1 As Class1) As Boolean
    Equals = Me.abc = cls1.abc
End Function

Function DebugPrint()
    Debug.Print abc_
End Function
