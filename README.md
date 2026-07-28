# WhenAppStart

## Introduction
Automatically execute the configured script when the configured application starts up

## Configuration

The configuration format in handle.conf is as follows:
```
DirName|PackageName|ScriptList
```

For example:
```:handle.conf
example|com.android.setting|script.sh:123456789,script.sh:123456789
```

| Name | Format | Description |
|:-------|:-------|:-------|
| DirName | None | This is the alias for the folder inside /assets/. Usually, you can use the application name as a substitute, but it's best not to include spaces. |
| PackageName | None | The package name of the application that will execute the scripts below. |
| ScriptList | script:args | You can put the file you want to execute before the colon (it must be executable by sh). Separate multiple files with ",". Use "\\n" instead if args need to contain a newline. However, currently args do not support anything like "\"" or "\'", you can only pass raw values. |
