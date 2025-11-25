typedef struct {
  struct TypeB* b_member;
} TypeA;

struct TypeB {
    TypeA* a_member;
};

// translate
//
// pub const struct_TypeB = extern struct {
//     a_member: [*c]TypeA = null,
// };
// pub const TypeA = extern struct {
//     b_member: [*c]struct_TypeB = null,
// };
