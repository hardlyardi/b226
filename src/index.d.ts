export type Ent<Lo = any> = number & {
    readonly __nominal: unique symbol;
    readonly __b2: Lo
}
export type Id<Lo = null> = Ent<Lo>;

export type OnAddHook = <Data>(entity: Ent, id: Ent<Data>, data: Data) => void
export type OnChangeHook = <Data>(entity: Ent, id: Ent<Data>, data: Data) => void
export type OnRemoveHook = <Data>(entity: Ent, id: Ent<Data>) => void

type Opt<T> = T | null

type Iter<T extends unknown[]> = IterableFunction<LuaTuple<[Ent, ...T]>>;

export type InferComponent<E> = E extends Ent<infer D>
    ? D
    : never;

type InferComponents<A extends Id[]> = { [K in keyof A]: InferComponent<A[K]> };

export type Query<T extends unknown[]> = {
    with: (self: Query<T>, ...Ent) => Query<T>;
    without: (self: Query<T>, ...Ent) => Query<T>;
    match: (self: Query<T>) => (arch) => boolean;
    archetypes: (self: Query<T>) => any[];
    entities: (self: Query<T>) => Iter<T>;
    archetypes_cached: (self: Query<T>) => any[];
    entities_cached: (self: Query<T>) => Iter<T>;
    observe_added: (self: Query<T>, callback: (arch) => void) => () => void;
    observe_removed: (self: Query<T>, callback: (arch) => void) => () => void;
    monitor_added_row: (self: Query<T>, callback: (ent, arch, row: number) => void) => () => void;
    monitor_removed_row: (self: Query<T>, callback: (ent, arch, row: number) => void) => () => void;
    monitor_added: (self: Query<T>, callback: (ent, id) => void) => () => void;
    monitor_removed: (self: Query<T>, callback: (ent) => void) => () => void;
} & Iter<T>;

export type ecs = {
    existed: (entity: Ent) => boolean;
    contains: (entity: Ent) => boolean;
    entity: () => Ent;
    in_use: (Ent) => boolean;
    get: (<A>(entity: Ent, component: Ent<A>) => A | null);
    bulk_get: (entity: Ent, components: { Ent }) => { any };
    has: (entity: Ent, A: Ent, ...Ent) => boolean;
    target: (entity: Ent, rel: Ent, idx?: number) => Opt<Ent>;
    parent: (entity: Ent) => Opt<Ent>;
    add: (entity: Ent, A: Ent) => void;
    bulk_add: (entity: Ent, components: { Ent }) => void;
    component: <Data>() => Ent<Data>;
    set: <Data>(entity: Ent, component: Ent<Data>, data: Data) => void;
    bulk_set: (entity: Ent, components: { Ent }, values: { any }) => void;
    remove: (entity: Ent, component: Ent) => void;
    bulk_remove: (entity: Ent, components: { Ent }) => void;
    clear: (entity: Ent, destroy?: boolean) => void;
    cleanup: () => void;
    ensure_dense_archetypes: () => void;
    each: (id: Ent) => () => Opt<Ent>;
    query: (<T extends Id[]>(...components: T) => Query<InferComponents<T>>);
    internal: {
        ROOT_ARCHETYPE: any;
        agraph_root: any;
        agraph: any;
        arch_has_empty_rows: any;
        arch_scheduled_for_deletion: any;
        archetypes: any;
        archetypes_count: any;
        observe_arch_added: any;
        observe_arch_removed: any;
        cindex: any;
        eindex_dense: any;
        eindex_sparse: any;
        eindex_alive_count: any;
        eindex_id_top: any;
        user_components_count: any;
        eindex_try_any_record: any;
        eindex_try_matching_record: any;
        eindex_alive_eh: any;
        ecs_existed: any;
        ecs_contains: any;
        ent_try_latest_alive: any;
        eindex_new_id_alive: any;
        ecs_entity: any;
        ecs_in_use: any;
        arch_ensure_dense: any;
        arch_move: any;
        ent_move: any;
        fetch_at_row: any;
        ecs_get: any;
        ecs_bulk_get: any;
        ecs_has: any;
        ent_has_inline: any;
        ecs_target: any;
        ecs_parent: any;
        id_record_new: any;
        id_record_ensure: any;
        id_record_arch_append: any;
        ids_page_mapping: any;
        pagebuff_from_mapping: any;
        list_from_buff: any;
        arch_new: any;
        agraph_ensure: any;
        agraph_ensure_arch: any;
        binary_search: any;
        binary_insert: any;
        agraph_traverse_add: any;
        agraph_traverse_add_ensure: any;
        agraph_traverse_rem: any;
        agraph_traverse_rem_ensure: any;
        ecs_add: any;
        ecs_bulk_add: any;
        ecs_component: any;
        ecs_set: any;
        ecs_bulk_set: any;
        ecs_remove: any;
        ecs_bulk_remove: any;
        ecs_clear: any;
        arch_delete: any;
        ecs_cleanup: any;
        ecs_ensure_dense_archetypes: any;
        query_matcher_cache: any;
        query_matcher_hash: any;
        query_matcher_new: any;
        query_matcher_ensure: any;
        ecs_each: any;
        queryobj: any;
        queryobj_metatable: any;
        ecs_query: any;
    }
}

export namespace b226 {
    function ecs(
        _?: any,
        disable_auto_ensure_dense?: boolean,
    ): ecs;
    function pair<High, Low>(hi: Ent<High>, lo: Ent<Low>): Ent;
    const Component: Id;
    const Name: Id<string>;
    const Wildcard: Id;
    const ChildOf: Id;
    const DeleteOnClear: Id;
    const DeleteOnDelete: Id;
    const DeleteOnClearTarget: Id;
    const DeleteOnDeleteTarget: Id;
    const DeleteOnClearAsRelation: Id;
    const DeleteOnDeleteAsRelation: Id;
    const OnClear: Id;
    const OnDelete: Id;
    const OnClearTarget: Id;
    const OnDeleteTarget: Id;
    const CleanupDelete: Id;
    const OnAdd: Id<OnAddHook>;
    const OnChange: Id<OnChangeHook>;
    const OnRemove: Id<OnRemoveHook>;
    const Exclusive: Id;
    export namespace internal {
        const hks_add: any;
        const hks_change: any;
        const hks_remove: any;
        const idr_flags: any;
        const idr_hooks: any;
        const idr_arch_sparse: any;
        const idr_arch_count: any;
        const idr_dense_cached: any;
        const idr_dense_column: any;
        const idr_dense_counts: any;
        const idr_monitors: any;
        const INDEX: any;
        const NULL_ARRAY: any;
        const NULLPTR: any;
        const F64_BYTES: any;
        const IDFLAG_TAG: any;
        const IDFLAG_DELETE_ONCLEAR: any;
        const IDFLAG_DELETE_ONDELETE: any;
        const IDFLAG_DELETE_ONCLEARTARGET: any;
        const IDFLAG_DELETE_ONDELETETARGET: any;
        const IDFLAG_DELETE_ONCLEARASRELATION: any;
        const IDFLAG_DELETE_ONDELETEASRELATION: any;
        const IDFLAG_EXCLUSIVE: any;
        const IDFLAG_HOOK_ONADD: any;
        const IDFLAG_HOOK_ONCHANGE: any;
        const IDFLAG_HOOK_ONREM: any;
        const EMASK_LO: any;
        const EMASK_GENERATION: any;
        const EPAIR_OFFSET: any;
        const COMPONENT_PAGE_SIZE: any;
        const COMPONENT_PAGE_RECORD_SIZE: any;
        const MAX_PAGED_COMPONENT: any;
        const MAX_COMPONENT: any;
        const B2Component: any;
        const B2Name: any;
        const B2Exclusive: any;
        const B2Wildcard: any;
        const B2ChildOf: any;
        const B2OnClear: any;
        const B2OnDelete: any;
        const B2OnClearTarget: any;
        const B2OnDeleteTarget: any;
        const B2OnClearAsRelation: any;
        const B2OnDeleteAsRelation: any;
        const B2CleanupDelete: any;
        const B2OnAdd: any;
        const B2OnRemove: any;
        const B2OnChange: any;
        const ASSERT: any;
        const ORDERED_HASH: any;
        const ENT_LO: any;
        const ENT_HI: any;
        const ENT_PAIR: any;
        const ENT_PAIR_EH: any;
        const ENT_PAIR_HI: any;
        const ENT_PAIR_LO: any;
        const ARCH_APPEND: any;
        const ENT_INCREMENT_GENERATION: any;
        const RECORD_ENSURE_ROW: any;
        const ecs_new: any;
    }
}

export default b226;
