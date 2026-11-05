import 'package:equatable/equatable.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/expense.dart';
import '../../../shared_living/data/models/member.dart';

abstract class ExpensesState extends Equatable {
  const ExpensesState();

  @override
  List<Object?> get props => [];
}

class ExpensesInitial extends ExpensesState {
  const ExpensesInitial();
}

class ExpensesLoading extends ExpensesState {
  const ExpensesLoading();
}

class ExpensesLoaded extends ExpensesState {
  final List<Expense> expenses;
  final BalancesResponse balances;
  final List<Member> members;
  final bool isSubmitting;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;

  const ExpensesLoaded({
    required this.expenses,
    required this.balances,
    required this.members,
    this.isSubmitting = false,
    this.actionSuccessMessage,
    this.actionErrorMessage,
  });

  ExpensesLoaded copyWith({
    List<Expense>? expenses,
    BalancesResponse? balances,
    List<Member>? members,
    bool? isSubmitting,
    String? actionSuccessMessage,
    String? actionErrorMessage,
    bool clearMessages = false,
  }) {
    return ExpensesLoaded(
      expenses: expenses ?? this.expenses,
      balances: balances ?? this.balances,
      members: members ?? this.members,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionSuccessMessage:
          clearMessages ? null : (actionSuccessMessage ?? this.actionSuccessMessage),
      actionErrorMessage:
          clearMessages ? null : (actionErrorMessage ?? this.actionErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        expenses,
        balances,
        members,
        isSubmitting,
        actionSuccessMessage,
        actionErrorMessage,
      ];
}

class ExpensesError extends ExpensesState {
  final String message;

  const ExpensesError({required this.message});

  @override
  List<Object?> get props => [message];
}
