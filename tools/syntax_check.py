"""Syntax-only check of every Swift file (no type checking). Needs: pip install tree-sitter tree-sitter-swift"""
import glob, sys
import tree_sitter_swift as tss
from tree_sitter import Language, Parser

parser = Parser(Language(tss.language()))

def errors(node, src, out):
    if node.type == "ERROR" or node.is_missing:
        out.append((node.start_point[0] + 1, src[node.start_byte:node.end_byte][:60].decode("utf8", "ignore")))
    for child in node.children:
        errors(child, src, out)

bad = 0
for path in sorted(glob.glob("ScooterLog/**/*.swift", recursive=True)):
    src = open(path, "rb").read()
    out = []
    errors(parser.parse(src).root_node, src, out)
    print(("OK   " if not out else "ERR  ") + path, out[:3])
    bad += bool(out)
print("files with syntax errors:", bad)
sys.exit(1 if bad else 0)
