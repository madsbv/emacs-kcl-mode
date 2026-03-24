# This is a comprehensive KCL test file exercising all syntax constructs.
# Used for validating emacs kcl-mode font-lock highlighting.

# --- Imports ---
import regex
import k8s.apimachinery.pkg.apis.meta.v1
import k8s.apimachinery.pkg.apis.meta.v1 as metav1

# --- Type aliases ---
type StringOrInt = str | int
type NameList = [str]

# --- Schema definitions ---
schema Person:
    """A person with a name and age.

    Attributes
    ----------
    name : str
        The person's name.
    age : int
        The person's age.
    """
    name: str
    age: int
    labels?: {str: str}
    friends?: [Person]

    check:
        age > 0, "age must be positive"
        age < 200
        len(name) > 0

# --- Mixin ---
mixin MetadataMixin:
    """Adds metadata fields."""
    metadata?: {str: str}

# --- Protocol ---
protocol Serializable:
    """Protocol for serializable objects."""
    to_json: () -> str

# --- Rule ---
rule PositiveAge:
    """Validates age is positive."""
    age > 0, "age must be positive"

# --- Schema with inheritance, mixin, decorator ---
@deprecated
schema Employee(Person):
    """Employee extends Person."""

    mixin [
        MetadataMixin,
    ]

    company: str
    salary: float
    is_active: bool = True
    role?: str

    check:
        salary > 0.0

# --- Schema with index signature ---
schema Config:
    """Configuration with dynamic keys."""
    [str]: any

# --- Constants and literals ---
name = "Alice"
raw_str = r"raw string with \n no escape"
single_quoted = 'single quoted'
triple_double = """
triple
double
quoted
"""
triple_single = '''
triple
single
quoted
'''

# --- Numbers ---
decimal = 42
negative = -17
hex_num = 0xFF
oct_num = 0o77
bin_num = 0b1010
float_num = 3.14
float_exp = 1.5e10
float_neg_exp = 2.0e-3

# Numbers with SI multipliers
mem_ki = 512Ki
mem_mi = 256Mi
mem_gi = 2Gi
cpu_m = 500m
size_k = 10k
size_K = 10K
size_M = 100M
size_G = 1G
size_T = 1T
size_P = 1P
size_n = 100n
size_u = 100u

# --- Boolean and special values ---
flag_true = True
flag_false = False
nothing = None
not_defined = Undefined

# --- String interpolation ---
greeting = "Hello, ${name}!"
complex_interp = "Age is ${person.age + 1}"

# --- Operators ---
sum = 1 + 2
diff = 10 - 3
product = 4 * 5
power = 2 ** 10
quotient = 10 / 3
floor_div = 10 // 3
remainder = 10 % 3
left_shift = 1 << 4
right_shift = 16 >> 2
bit_and = 0xFF & 0x0F
bit_or = 0xF0 | 0x0F
bit_xor = 0xFF ^ 0x0F
bit_not = ~0xFF

# --- Comparison and logical ---
is_equal = 1 == 1
not_equal = 1 != 2
less = 1 < 2
greater = 2 > 1
leq = 1 <= 1
geq = 2 >= 1
logical_and = True and False
logical_or = True or False
logical_not = not True
identity = None is None
membership = "a" in ["a", "b"]
not_in = "c" not in ["a", "b"]
is_not = 1 is not None

# --- Conditional expressions ---
result = "yes" if flag_true else "no"

# --- If statement ---
if flag_true:
    x = 1
elif flag_false:
    x = 2
else:
    x = 3

# --- For / comprehensions ---
numbers = [1, 2, 3, 4, 5]
doubled = [n * 2 for n in numbers]
filtered = [n for n in numbers if n > 2]

# --- Quantifier expressions ---
all_positive = all n in numbers {
    n > 0
}
any_large = any n in numbers {
    n > 4
}
mapped = map n in numbers {
    n * 10
}
selected = filter n in numbers {
    n > 2
}

# --- Dict and list ---
empty_list = []
empty_dict = {}
person_dict = {
    name: "Bob"
    age: 30
    "quoted-key": "value"
}

# --- Schema instantiation ---
alice = Person {
    name: "Alice"
    age: 30
    labels: {
        role: "engineer"
    }
}

bob = Employee {
    name: "Bob"
    age: 25
    company: "ACME"
    salary: 100000.0
}

# --- Lambda ---
add = lambda x: int, y: int -> int {
    x + y
}

transform = lambda items: [int] -> [int] {
    [i * 2 for i in items]
}

# --- Assert ---
assert alice.age > 0, "Alice must have positive age"
assert bob.name == "Bob" if bob.is_active

# --- Unification ---
config: Config {
    key1: "value1"
    key2: "value2"
}

# --- Optional field access ---
maybe_name = alice?.name
maybe_item = numbers?[0]

# --- Type annotations ---
typed_str: str = "hello"
typed_int: int = 42
typed_float: float = 3.14
typed_bool: bool = True
typed_list: [str] = ["a", "b"]
typed_dict: {str: int} = {a: 1}
typed_any: any = "anything"
typed_union: str | int = 42
typed_func: (int, int) -> int = add

# --- Multi-line and escaped strings ---
escaped = "line1\nline2\ttab\\backslash\"quote"
unicode_esc = "\u0041\U00000042"
hex_esc = "\x41"
octal_esc = "\101"

# --- Comments at various positions ---
x1 = 1  # inline comment
# Full line comment
