@@
identifier C;
@@
 int C(int i) {
  ...
  if(C()) { ... }
  ...
+ if(UnitTest()) {
+   int c;
+   C();
+  }
 }


@@
identifier TestMethod;
identifier name;
@@

 int C(int i) {
  ...
  UnitTestEntry(name);
  if(TestMethod()) { ... }
  ...
  if(UnitTest()) {
   int c;
   ...
+  c = C();
+  Console.WriteLine("invoking test", name);
+  c.TestMethod();
  }
 }
