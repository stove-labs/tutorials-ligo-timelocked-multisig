type proposal_definition is record
    destination: address ;
    amount: tez ;
    expires_at: timestamp ;
end

type proposal is option(proposal_definition) ;

(* Storage *)
type storage_type is record
    current_proposal: proposal ;
    approved_by: set(address) ;
    owners: set(address) ;
end

(* Parameter *)
type action is
    | Propose of proposal_definition
    | Approve of proposal_definition
    | Execute of unit

(*
    Helpers
*)
function owners_only (const owners : set(address)) : unit is 
    block {
        if not set_mem(sender, owners) then failwith("You are not allowed to call the contract")
        else skip
    } with (Unit);
function proposals_are_equal (const first_proposal : proposal_definition; const second_proposal : proposal_definition) : bool is
    block {
        const equality_set : set(bool) = set 
                (first_proposal.expires_at = second_proposal.expires_at);
                (first_proposal.destination = second_proposal.destination); 
                (first_proposal.amount = second_proposal.amount); 
            end;
    } with set_mem(False, equality_set)
function proposal_is_expired (const proposal : proposal_definition) : bool is
    block {skip} with (proposal.expires_at <= now)
function delete_approvals(const store : storage_type) : storage_type is
    block {
        const empty_set : set(address) = set end;
        store.approved_by := empty_set;
    } with store


function approval_already_exists (const approved_by: set(address)) : bool is
    block {skip} with (set_mem(sender, approved_by))

function add_approval (const store : storage_type; const approve_by: address) : storage_type is
    block {
        store.approved_by := set_add(approve_by, store.approved_by)
    } with (store)

function is_approved (const approved_by: set(address); const owners: set(address)) : bool is 
    block {skip} with (size(approved_by) = size(owners))

(*
    Entrypoints
*)
function propose (const new_proposal : proposal_definition ; const store : storage_type) : (list(operation) * storage_type) is
  block { 
      case store.current_proposal of
        | None -> begin 
            // proposal does not exist, create a new one
            store := delete_approvals(store);
            store.current_proposal := Some(new_proposal)
        end
        | Some (current_proposal) -> begin
            if proposal_is_expired(current_proposal) then
                begin
                    // proposal exists, but is expired, override with a new one
                    store := delete_approvals(store);
                    store.current_proposal := Some(new_proposal)
                end
            else failwith ("An unexpired proposal already exists, please wait until it expires before trying again")
        end
      end;
  } with ((nil : list(operation)), store)

function approve (const proposal_to_approve: proposal_definition ; const store : storage_type) : (list(operation) * storage_type) is
  block {
      const current_proposal : proposal = store.current_proposal;
      case current_proposal of
        | None -> failwith("There is no proposal to approve")
        | Some (current_proposal) -> begin
            if not proposals_are_equal(proposal_to_approve, current_proposal) then 
                begin 
                    failwith("You are trying to approve a different proposal") 
                end
            else 
                begin
                    if not approval_already_exists(store.approved_by) then 
                        store := add_approval(store, sender)
                    else failwith("You have already approved this proposal");
                end
        end
      end;
  } with ((nil : list(operation)), store)

function execute (const p : unit; const store : storage_type) : (list(operation) * storage_type) is
    block {
        const operations : list(operation) = list end;
        
        case store.current_proposal of
        | None -> failwith("You are trying to execute a non-existing proposal")
        | Some (current_proposal) -> begin 
                if is_approved(store.approved_by, store.owners) then 
                    begin 
                        const proposed_destination : contract(unit) = get_contract(current_proposal.destination);
                        const proposedTransaction : operation = transaction(unit, current_proposal.amount, proposed_destination);
                        operations := list
                            proposedTransaction
                        end;
                    end
                else skip;
            end
        end

    } with (operations, store)

function main (const action : action ; const store : storage_type) : (list(operation) * storage_type) is
  block {
      owners_only(store.owners);
  } with (
    case action of
        | Propose (new_proposal) -> propose(new_proposal, store)
        | Approve (proposal) -> approve(proposal, store)
        | Execute (p) -> execute(p,store)
    end)