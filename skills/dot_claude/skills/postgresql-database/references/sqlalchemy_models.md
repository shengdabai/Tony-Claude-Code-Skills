# SQLAlchemy Model Definitions

## Basic Model Structure

### Simple Model
```python
from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()

class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}')>"
```

### Using Modern Declarative Syntax (SQLAlchemy 2.0+)
```python
from datetime import datetime
from typing import Optional, List
from sqlalchemy import String, DateTime, Boolean, ForeignKey, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = 'users'

    # Type annotations provide the column types
    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    is_active: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(),
        onupdate=func.now()
    )

    # Relationships (covered below)
    posts: Mapped[List["Post"]] = relationship(back_populates="author")
```

## Relationships

### One-to-Many Relationship
```python
from sqlalchemy import ForeignKey
from sqlalchemy.orm import relationship

class Author(Base):
    __tablename__ = 'authors'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))

    # One author has many books
    books: Mapped[List["Book"]] = relationship(
        back_populates="author",
        cascade="all, delete-orphan"
    )

class Book(Base):
    __tablename__ = 'books'

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(255))
    author_id: Mapped[int] = mapped_column(ForeignKey('authors.id'))

    # Many books belong to one author
    author: Mapped["Author"] = relationship(back_populates="books")

# Usage:
# author = Author(name="J.K. Rowling")
# book = Book(title="Harry Potter", author=author)
# session.add(author)  # Also adds book due to cascade
```

### Many-to-Many Relationship
```python
from sqlalchemy import Table, Column, ForeignKey

# Association table
student_courses = Table(
    'student_courses',
    Base.metadata,
    Column('student_id', ForeignKey('students.id'), primary_key=True),
    Column('course_id', ForeignKey('courses.id'), primary_key=True),
    Column('enrolled_at', DateTime, default=datetime.utcnow),
    Column('grade', String(2))
)

class Student(Base):
    __tablename__ = 'students'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))

    # Many-to-many with courses
    courses: Mapped[List["Course"]] = relationship(
        secondary=student_courses,
        back_populates="students"
    )

class Course(Base):
    __tablename__ = 'courses'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    code: Mapped[str] = mapped_column(String(20), unique=True)

    # Many-to-many with students
    students: Mapped[List["Student"]] = relationship(
        secondary=student_courses,
        back_populates="courses"
    )

# Usage:
# student = Student(name="Alice")
# course = Course(name="Mathematics", code="MATH101")
# student.courses.append(course)
```

### Many-to-Many with Association Object Pattern
```python
class Enrollment(Base):
    __tablename__ = 'enrollments'

    student_id: Mapped[int] = mapped_column(
        ForeignKey('students.id'),
        primary_key=True
    )
    course_id: Mapped[int] = mapped_column(
        ForeignKey('courses.id'),
        primary_key=True
    )
    enrolled_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    grade: Mapped[Optional[str]] = mapped_column(String(2))

    # Relationships to parent tables
    student: Mapped["Student"] = relationship(back_populates="enrollments")
    course: Mapped["Course"] = relationship(back_populates="enrollments")

class Student(Base):
    __tablename__ = 'students'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))

    enrollments: Mapped[List["Enrollment"]] = relationship(
        back_populates="student",
        cascade="all, delete-orphan"
    )

    # Convenience property
    @property
    def courses(self):
        return [enrollment.course for enrollment in self.enrollments]

class Course(Base):
    __tablename__ = 'courses'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))

    enrollments: Mapped[List["Enrollment"]] = relationship(
        back_populates="course",
        cascade="all, delete-orphan"
    )

# Usage:
# student = Student(name="Alice")
# course = Course(name="Mathematics")
# enrollment = Enrollment(student=student, course=course, grade="A")
# session.add(enrollment)
```

### Self-Referential Relationship
```python
class Category(Base):
    __tablename__ = 'categories'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    parent_id: Mapped[Optional[int]] = mapped_column(ForeignKey('categories.id'))

    # Parent relationship
    parent: Mapped[Optional["Category"]] = relationship(
        remote_side=[id],
        back_populates="children"
    )

    # Children relationship
    children: Mapped[List["Category"]] = relationship(
        back_populates="parent",
        cascade="all, delete-orphan"
    )

# Usage:
# electronics = Category(name="Electronics")
# laptops = Category(name="Laptops", parent=electronics)
# gaming_laptops = Category(name="Gaming Laptops", parent=laptops)
```

## Column Types and Options

### Common Column Types
```python
from sqlalchemy import (
    Integer, BigInteger, SmallInteger,
    String, Text,
    Boolean,
    Date, DateTime, Time, Interval,
    Numeric, Float,
    LargeBinary,
    Enum
)
from sqlalchemy.dialects.postgresql import (
    UUID, JSONB, ARRAY, INET, CIDR, MACADDR
)
import uuid
import enum

class UserRole(enum.Enum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"

class User(Base):
    __tablename__ = 'users'

    # Numeric types
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    big_number: Mapped[int] = mapped_column(BigInteger)
    small_number: Mapped[int] = mapped_column(SmallInteger)
    price: Mapped[float] = mapped_column(Numeric(10, 2))  # Precision 10, scale 2

    # String types
    username: Mapped[str] = mapped_column(String(50))  # VARCHAR(50)
    bio: Mapped[Optional[str]] = mapped_column(Text)   # TEXT (unlimited length)

    # Boolean
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Date/Time types
    birth_date: Mapped[date] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    login_time: Mapped[time] = mapped_column(Time)

    # Enum
    role: Mapped[UserRole] = mapped_column(Enum(UserRole))

    # PostgreSQL-specific types
    id_uuid: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        default=uuid.uuid4
    )
    settings: Mapped[dict] = mapped_column(JSONB)
    tags: Mapped[list] = mapped_column(ARRAY(String))
    ip_address: Mapped[str] = mapped_column(INET)

    # Binary data
    avatar: Mapped[Optional[bytes]] = mapped_column(LargeBinary)
```

### Column Constraints and Options
```python
from sqlalchemy import CheckConstraint, UniqueConstraint, Index

class Product(Base):
    __tablename__ = 'products'

    id: Mapped[int] = mapped_column(primary_key=True)

    # Unique constraint
    sku: Mapped[str] = mapped_column(String(50), unique=True)

    # Not null
    name: Mapped[str] = mapped_column(String(255), nullable=False)

    # Default value
    in_stock: Mapped[bool] = mapped_column(default=True)

    # Server-side default
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    # Auto-increment (default for Integer primary key)
    # Custom sequence
    custom_id: Mapped[int] = mapped_column(autoincrement=True)

    # Price with check constraint
    price: Mapped[float] = mapped_column(Numeric(10, 2))

    # Table-level constraints
    __table_args__ = (
        CheckConstraint('price >= 0', name='check_price_positive'),
        UniqueConstraint('name', 'sku', name='uq_product_name_sku'),
        Index('ix_product_name_lower', func.lower('name')),
    )
```

## Advanced Patterns

### Mixins for Common Columns
```python
from sqlalchemy.ext.declarative import declared_attr
from datetime import datetime

class TimestampMixin:
    """Adds created_at and updated_at timestamps to models."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False
    )

class SoftDeleteMixin:
    """Adds soft delete functionality."""

    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime)

    def soft_delete(self):
        self.deleted_at = datetime.utcnow()

    @property
    def is_deleted(self):
        return self.deleted_at is not None

# Use mixins
class User(TimestampMixin, SoftDeleteMixin, Base):
    __tablename__ = 'users'

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50))
    # Automatically has created_at, updated_at, deleted_at
```

### Hybrid Properties
```python
from sqlalchemy.ext.hybrid import hybrid_property, hybrid_method

class User(Base):
    __tablename__ = 'users'

    id: Mapped[int] = mapped_column(primary_key=True)
    first_name: Mapped[str] = mapped_column(String(50))
    last_name: Mapped[str] = mapped_column(String(50))
    _password_hash: Mapped[str] = mapped_column('password_hash', String(255))

    # Hybrid property - works in both Python and SQL
    @hybrid_property
    def full_name(self):
        return f"{self.first_name} {self.last_name}"

    @full_name.expression
    def full_name(cls):
        return func.concat(cls.first_name, ' ', cls.last_name)

    # Password property with setter
    @hybrid_property
    def password(self):
        raise AttributeError("Password is write-only")

    @password.setter
    def password(self, plaintext):
        from passlib.hash import bcrypt
        self._password_hash = bcrypt.hash(plaintext)

    # Hybrid method
    @hybrid_method
    def verify_password(self, plaintext):
        from passlib.hash import bcrypt
        return bcrypt.verify(plaintext, self._password_hash)

# Usage in Python:
# user = session.query(User).first()
# print(user.full_name)  # "John Doe"

# Usage in SQL:
# users = session.query(User).filter(User.full_name == "John Doe").all()
```

### Table Inheritance

#### Single Table Inheritance
```python
class Employee(Base):
    __tablename__ = 'employees'

    id: Mapped[int] = mapped_column(primary_key=True)
    type: Mapped[str] = mapped_column(String(50))
    name: Mapped[str] = mapped_column(String(100))

    # Discriminator
    __mapper_args__ = {
        'polymorphic_identity': 'employee',
        'polymorphic_on': type
    }

class Engineer(Employee):
    engineer_level: Mapped[Optional[int]] = mapped_column(Integer)

    __mapper_args__ = {
        'polymorphic_identity': 'engineer',
    }

class Manager(Employee):
    department: Mapped[Optional[str]] = mapped_column(String(50))

    __mapper_args__ = {
        'polymorphic_identity': 'manager',
    }

# Query returns correct subclass instances
# engineers = session.query(Employee).filter(Employee.type == 'engineer').all()
# isinstance(engineers[0], Engineer)  # True
```

#### Joined Table Inheritance
```python
class Person(Base):
    __tablename__ = 'persons'

    id: Mapped[int] = mapped_column(primary_key=True)
    type: Mapped[str] = mapped_column(String(50))
    name: Mapped[str] = mapped_column(String(100))

    __mapper_args__ = {
        'polymorphic_identity': 'person',
        'polymorphic_on': type
    }

class Customer(Person):
    __tablename__ = 'customers'

    id: Mapped[int] = mapped_column(ForeignKey('persons.id'), primary_key=True)
    account_balance: Mapped[float] = mapped_column(Numeric(10, 2))

    __mapper_args__ = {
        'polymorphic_identity': 'customer',
    }

class Employee(Person):
    __tablename__ = 'employees'

    id: Mapped[int] = mapped_column(ForeignKey('persons.id'), primary_key=True)
    employee_id: Mapped[str] = mapped_column(String(20))

    __mapper_args__ = {
        'polymorphic_identity': 'employee',
    }
```

### Association Proxy
```python
from sqlalchemy.ext.associationproxy import association_proxy

class User(Base):
    __tablename__ = 'users'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))

    # Relationship to association object
    user_keywords: Mapped[List["UserKeyword"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan"
    )

    # Proxy to access keywords directly
    keywords = association_proxy(
        'user_keywords',
        'keyword',
        creator=lambda keyword: UserKeyword(keyword=keyword)
    )

class Keyword(Base):
    __tablename__ = 'keywords'

    id: Mapped[int] = mapped_column(primary_key=True)
    keyword: Mapped[str] = mapped_column(String(50), unique=True)

    user_keywords: Mapped[List["UserKeyword"]] = relationship(
        back_populates="keyword"
    )

class UserKeyword(Base):
    __tablename__ = 'user_keywords'

    user_id: Mapped[int] = mapped_column(
        ForeignKey('users.id'),
        primary_key=True
    )
    keyword_id: Mapped[int] = mapped_column(
        ForeignKey('keywords.id'),
        primary_key=True
    )

    user: Mapped["User"] = relationship(back_populates="user_keywords")
    keyword: Mapped["Keyword"] = relationship(back_populates="user_keywords")

# Usage - much simpler!
# user.keywords.append("python")
# user.keywords.append("sqlalchemy")
# print(user.keywords)  # ["python", "sqlalchemy"]
```

### Composite Columns
```python
from sqlalchemy.orm import composite

class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __composite_values__(self):
        return self.x, self.y

    def __eq__(self, other):
        return isinstance(other, Point) and \
               other.x == self.x and \
               other.y == self.y

class Location(Base):
    __tablename__ = 'locations'

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))

    # Individual columns
    x: Mapped[int] = mapped_column(Integer)
    y: Mapped[int] = mapped_column(Integer)

    # Composite
    point = composite(Point, x, y)

# Usage:
# loc = Location(name="Home", point=Point(10, 20))
# print(loc.point.x)  # 10
```

## Events and Listeners

```python
from sqlalchemy import event

class User(Base):
    __tablename__ = 'users'

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50))
    username_lower: Mapped[str] = mapped_column(String(50), index=True)

# Before insert/update event
@event.listens_for(User, 'before_insert')
@event.listens_for(User, 'before_update')
def normalize_username(mapper, connection, target):
    target.username_lower = target.username.lower()

# After insert event
@event.listens_for(User, 'after_insert')
def log_user_creation(mapper, connection, target):
    print(f"New user created: {target.username}")

# Load event
@event.listens_for(User, 'load')
def on_user_load(target, context):
    print(f"User loaded: {target.username}")
```

## Model Validation

```python
from sqlalchemy.orm import validates
from email_validator import validate_email

class User(Base):
    __tablename__ = 'users'

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50))
    email: Mapped[str] = mapped_column(String(255))
    age: Mapped[int] = mapped_column(Integer)

    @validates('email')
    def validate_email_address(self, key, address):
        try:
            valid = validate_email(address)
            return valid.email
        except Exception:
            raise ValueError(f"Invalid email address: {address}")

    @validates('age')
    def validate_age(self, key, age):
        if age < 0 or age > 150:
            raise ValueError(f"Invalid age: {age}")
        return age

    @validates('username')
    def validate_username(self, key, username):
        if len(username) < 3:
            raise ValueError("Username must be at least 3 characters")
        return username
```
