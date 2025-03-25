
# memo

## arm64

ref: https://www.mztn.org/dragon/arm6403reg.html

31個の64bit汎用レジスタをもつ。(x0 - x30, w0 - w30)
w0は32bitのレジスタ名, x0は64bit。
32bitの場合は上位32bitを0クリアする。
x30はlinkregister、bl 命令の戻りアドレスをもつ

BL: Branch with LinkはPC相対オフセットに分岐し、レジスタX30をPC+4に設定します。これはサブルーチン呼び出しであることを示唆しています。
詳細については、コンテキストメニューで確認できます。

add, subは引数3つ必要

# c compiler online

https://godbolt.org/
