# Lambda
Implement simple anonimus function.


## How to use
~~~
    Dim res
    res = Lambda(1, "x=>x ^ x + 1").Evaluate
    Debug.Print "The result is... " & res

    Dim lam As New Lambda, v
    v = 3
    DebugPrint lam(v, "x=>x + 3")
~~~

# Features
 - Evaluate values or class by using "lambda string"
 - After initialize, evaluating by Evaluate() 
 - Can pass Lambda as argument of function.
 - Not support some (General functions, multi arguments, etc...) 
 
## Files
 - You can import these files to your project
    - Lambda.cls
 - For only sample
    - Sample.bas
    - Class1.cls
    - Class2.cls

<br>
 * Specification may be changed.

## Japanese Note

<br>
作成中
