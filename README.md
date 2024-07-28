# Lambda
Implement simple anonimus function.


## How to use
~~~
    Dim res
    res = Lambda(1, "x=>x ^ x + 1").Evaluate
    Debug.Print "The result is... " & res

    res = Lambda(Array(1, 2), "(x,y) => x * y + 1").Evaluate
    Debug.Print "The result is... " & res

    Dim lam As New Lambda, v
    v = 3
    DebugPrint lam(v, "x=>x + 3")
~~~

# Features
 - Evaluate values or class by using "string"
 - After initialize, evaluating by Evaluate() 
 - Can pass Lambda as arguments of function.
 - Not support some (assign value, multi lines, etc...) 
 
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
- VBAで簡易的な無名関数を使えるようにします
- 文字列でコードを記述します
- いくつかのVBA メソッドをサポートしています
- 変数への値の代入、複数行は現在サポートしていません

