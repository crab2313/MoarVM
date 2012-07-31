
# This class builds up the QAST representing the
# construction of the NQPCursor and related types.
# Below the class are several "shortcut" routines 
# that facilitate QAST construction, and several
# routines that build up classes' method bodies
class NQPCursorQAST {
    method build_types() {
        
        my @ins := nqp::list();
        
        merge_qast(@ins, simple_type_from_repr( 'NQPint', 'P6int'));
        my $int_type := local('NQPint');
        my $int_type_n := local('NQPint', 'type');
        
        merge_qast(@ins, simple_type_from_repr( 'NQPstr', 'P6str'));
        my $str_type := local('NQPstr');
        my $str_type_n := local('NQPstr', 'type');
        
        merge_qast(@ins, simple_type_from_repr( 'NQPCursor', 'P6opaque'));
        my $cursor_type := local('NQPCursor');
        my $cursor_type_n := local('NQPCursor', 'type');
        
        merge_qast(@ins, op('bind', locald('knowhowattr'), vm('knowhowattr') ));
        my $knowhowattr := local('knowhowattr');
        my $knowhowattr_n := local('knowhowattr', 'type');
        
        my @cursor_attr := [
            '$!orig',     $str_type_n,
            '$!target',   $str_type_n,
            '$!from',     $int_type_n,
            '$!pos',      $int_type_n,
            '$!match',    $knowhowattr_n,
            '$!name',     $str_type_n,
            '$!bstack',   $knowhowattr_n,
            '$!cstack',   $knowhowattr_n,
            '$!regexsub', $knowhowattr_n
        ];
        
        for @cursor_attr -> $name, $attr_type {
            merge_qast(@ins, add_attribute(
                $knowhowattr, $cursor_type, $name, $attr_type));
        }
        
        # merge_qast(@ins, add_method($cursor_type, 'target', Cursor_target()));
        merge_qast(@ins, add_method($cursor_type, 'cursor_init', Cursor_cursor_init()));
        
        # class just to hold (multiple-return in the PIR generated by
        # QAST/Compiler.nqp) results of cursor_start method on Cursor.
        merge_qast(@ins, simple_type_from_repr( 'CursorStart', 'P6opaque'));
        my $cstart_type := local('CursorStart');
        
        my @cstart_attr := [
            '$!cur',      $knowhowattr_n,
            '$!tgt',      $str_type_n,
            '$!pos',      $int_type_n,
            '$!curclass', $knowhowattr_n,
            '$!bstack',   $knowhowattr_n,
            '$!i19',      $int_type_n
        ];
        
        for @cstart_attr -> $name, $attr_type {
            merge_qast(@ins, add_attribute(
                $knowhowattr, $cstart_type, $name, $attr_type));
        }
        
        merge_qast(@ins, compose($cursor_type));
        merge_qast(@ins, compose($int_type));
        merge_qast(@ins, compose($str_type));
        merge_qast(@ins, compose($cstart_type));
        
        merge_qast(@ins, Cursor_test_init($cursor_type));
            
        
        @ins
    }
    
    sub annot($file, $line, *@ins) {
        QAST::Annotated.new(:file($file), :line($line), :instructions(@ins));
    }
    
    sub ival($val, $named = "") { QAST::IVal.new( :value($val), :named($named) ) }
    sub nval($val, $named = "") { QAST::NVal.new( :value($val), :named($named) ) }
    sub sval($val, $named = "") { QAST::SVal.new( :value($val), :named($named) ) }
    sub bval($val, $named = "") { QAST::BVal.new( :value($val), :named($named) ) }
    
    sub push_ilist(@dest, $src) {
        nqp::splice(@dest, $src.instructions, +@dest, 0);
    }
    
    sub merge_qast(@ins, $qast) {
        my $mast := $*QASTCOMPILER.as_mast( $qast );
        # need a special release here because are bypassing the normal
        # Block, Stmts, or Stmt compile_all_the_stmts.
        $*REGALLOC.release_register($mast.result_reg, $mast.result_kind);
        push_ilist(@ins, $mast);
        $mast;
    }
    
    sub local($name, $named = "") {
        $named
            ?? QAST::Var.new( :name($name), :scope('local'), :named($named) )
            !! QAST::Var.new( :name($name), :scope('local') )
    }
    
    sub locald($name, $type = NQPMu) {
        QAST::Var.new( :name($name), :decl('var'), :returns($type), :scope('local') )
    }
    
    sub localp($name, :$type = NQPMu, :$default = NQPMu) {
        QAST::Var.new( :name($name), :decl('param'), :returns($type), :scope('local'), :default($default) )
    }
    
    sub localpn($name, :$type = NQPMu, :$default = NQPMu, :$named = "") {
        QAST::Var.new( :name($name), :decl('param'), :returns($type), :scope('local'), :default($default), :named($named) )
    }
    
    sub lexicald($name, $bind_val = NQPMu, $type = NQPMu) {
        my $var := QAST::Var.new( :name($name), :scope('lexical'), :returns($type), :decl('var') );
        $bind_val ?? op('bind', $var, $bind_val) !! $var;
    }
    
    sub lexical($name, $bind_val = NQPMu, $type = NQPMu) {
        my $var := QAST::Var.new( :name($name), :scope('lexical'), :returns($type) );
        $bind_val ?? op('bind', $var, $bind_val) !! $var;
    }
    
    sub attr($name, $obj, $type,) {
        QAST::Var.new( :name($name), $obj, $type, :scope('attribute') )
    }
    
    sub stmt(*@stmts) { QAST::Stmt.new( |@stmts ) }
    sub stmts(*@stmts) { QAST::Stmts.new( |@stmts ) }
    
    sub op($op, :$returns = NQPMu, *@args) {
        QAST::Op.new( :op($op), :returns($returns), |@args);
    }
    
    sub vm($op, *@args) { QAST::VM.new( :moarop($op), |@args) }
    sub uniq($str) { $*QASTCOMPILER.unique($str) }
    sub block(*@ins) { QAST::Block.new(|@ins) }
    
    sub simple_type_from_repr($type_name, $repr_str) {
        my $howlocal := uniq('how');
        stmts(
            locald($type_name),
            stmt(
                op('bind',
                    locald($howlocal),
                    vm('knowhow') ),
                lexicald($type_name,
                    op('bind',
                        local($type_name),
                        op('call',
                            vm('findmeth',
                                local($howlocal),
                                sval('new_type') ),
                            local($howlocal),
                            sval($type_name, 'name' ),
                            sval($repr_str, 'repr' ) ) ) ) ) )
    }
    
    sub add_attribute($knowhowattr, $type, $name_str, $attr_type_n) {
        my $howlocal := uniq('how');
        my $attr := uniq('attr');
        stmt(
            op('bind',
                locald($howlocal),
                vm('gethow',
                    $type ) ),
            op('call',
                vm('findmeth',
                    local($howlocal),
                    sval('add_attribute') ),
                local($howlocal),
                $type,
                op('call',
                    vm('findmeth',
                        $knowhowattr,
                        sval('new') ),
                    $knowhowattr,
                    sval($name_str, 'name'),
                    $attr_type_n ) ) )
    }
    
    sub compose($type) {
        my $howlocal := uniq('how');
        stmt(
            op('bind',
                locald($howlocal),
                vm('gethow',
                    $type ) ),
            op('call',
                vm('findmeth',
                    local($howlocal),
                    sval('compose') ),
                local($howlocal),
                $type ) )
    }
    
    sub add_method($type, $name_str, $qast_block) {
        my $howlocal := uniq('how');
        stmt(
            $qast_block,
            op('bind',
                locald($howlocal),
                vm('gethow',
                    $type ) ),
            op('call',
                vm('findmeth',
                    local($howlocal),
                    sval('add_method') ),
                local($howlocal),
                $type,
                sval($name_str),
                bval($qast_block) ) )
    }
    
    sub Cursor_target() {
        block(
            localp('self'),
            vm('getattr',
                local('self'),
                vm('getwhat',
                    local('self') ),
                sval('target'),
                ival(-1) ) )
    }
    
    sub Cursor_cursor_init() {
        block(
            localp('self'),
            localp('$target', :type(str) ),
            localp('$p', :type(NQPMu), :default(lexical('NQPint')) ), # boxed integer
            localpn('$c', :type(NQPMu), :default(lexical('NQPint')), :named('c') ), # boxed integer
            op('bind',
                locald('$new'),
                vm('create',
                    local('self') ) ),
            #op('bind',
            #    attr('$!orig',
            #        local('$new'),
            #        local('self') ),
            #    local('$target') )
        )
    }
    
    sub Cursor_test_init($type) {
        op('call',
            vm('findmeth',
                $type,
                sval('cursor_init') ),
            $type,
            sval('foo') )
    }
}

class QAST::Annotated is QAST::Node {
    has str $!file;
    has int $!line;
    has @!instructions;
    
    method new(:$file = '<anon>', :$line!, :@instructions!) {
        my $obj := nqp::create(self);
        nqp::bindattr_s($obj, QAST::Annotated, '$!file', $file);
        nqp::bindattr_i($obj, QAST::Annotated, '$!line', $line);
        nqp::bindattr($obj, QAST::Annotated, '@!instructions', @instructions);
        $obj
    }
    method file() { $!file }
    method line() { $!line }
    method instructions() { @!instructions }
}
