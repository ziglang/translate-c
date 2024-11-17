int main() {
    int i = 2;
    switch (i) {
        case 0: {
            case 2:{
                i += 2;}
            i += 1;
        }
    }
}

// translate
// expect=fail
//
// source.h:5:13: warning: TODO complex switch
//
// source.h:1:5: warning: unable to translate function, demoted to extern
// pub extern fn main() c_int;
