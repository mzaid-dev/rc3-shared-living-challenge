import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../shared_living/data/models/balances_response.dart';
import '../../../shared_living/data/models/expense.dart';
import '../../../shared_living/domain/repositories/shared_living_repository.dart';
import 'expenses_state.dart';

class ExpensesCubit extends Cubit<ExpensesState> {
  final SharedLivingRepository repository;

  ExpensesCubit({required this.repository}) : super(const ExpensesInitial());

  Future<void> loadExpensesAndBalances() async {
    emit(const ExpensesLoading());
    try {
      final members = await repository.getMembers();
      final expenses = await repository.getExpenses();
      final balances = await repository.getBalances();

      emit(ExpensesLoaded(
        expenses: expenses,
        balances: balances,
        members: members,
      ));
    } on AppFailure catch (f) {
      emit(ExpensesError(message: f.message));
    } catch (e) {
      emit(ExpensesError(message: e.toString()));
    }
  }

  Future<bool> addExpense(
    CreateExpenseDto dto, {
    required String idempotencyKey,
  }) async {
    if (state is! ExpensesLoaded) return false;
    final current = state as ExpensesLoaded;
    if (current.isSubmitting) return false;

    emit(current.copyWith(isSubmitting: true, clearMessages: true));
    try {
      final expense = await repository.addExpense(dto, idempotencyKey: idempotencyKey);
      final updatedExpenses = [expense, ...current.expenses];
      final updatedBalances = await repository.getBalances();

      emit(current.copyWith(
        expenses: updatedExpenses,
        balances: updatedBalances,
        isSubmitting: false,
        actionSuccessMessage: 'Logged "${expense.title}" for PKR ${expense.amount}.',
      ));
      return true;
    } on AppFailure catch (f) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: f.message));
      return false;
    } catch (e) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: e.toString()));
      return false;
    }
  }

  Future<bool> recordSettlement(
    SettlementRequestDto dto, {
    required String idempotencyKey,
  }) async {
    if (state is! ExpensesLoaded) return false;
    final current = state as ExpensesLoaded;
    if (current.isSubmitting) return false;

    emit(current.copyWith(isSubmitting: true, clearMessages: true));
    try {
      final result = await repository.recordSettlement(dto, idempotencyKey: idempotencyKey);
      emit(current.copyWith(
        balances: result.balances,
        isSubmitting: false,
        actionSuccessMessage: 'Settlement recorded! Transferred PKR ${dto.amount}.',
      ));
      return true;
    } on AppFailure catch (f) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: f.message));
      return false;
    } catch (e) {
      emit(current.copyWith(isSubmitting: false, actionErrorMessage: e.toString()));
      return false;
    }
  }
}
