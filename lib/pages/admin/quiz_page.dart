import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin.dart';
import '../../config/color_constants.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key});

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // 答题状态
  int _currentIdx = 0;
  List<String?> _selectedAnswers = []; // 每道题选中的答案字母 A/B/C/D
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ==================== 主框架 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('每日一测'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.text2,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: '今日答题'), Tab(text: '排行榜')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildQuizTab(), _buildLeaderboardTab()],
      ),
    );
  }

  // ==================== Tab 1: 今日答题 ====================

  Widget _buildQuizTab() {
    final async = ref.watch(todayQuizProvider);
    final actions = ref.read(adminActionsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.text2),
          const SizedBox(height: 12),
          Text('$e'.replaceFirst('Exception: ', ''), style: const TextStyle(color: AppColors.text2, fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(todayQuizProvider),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            child: const Text('重试'),
          ),
        ]),
      ),
      data: (data) {
        if (data.done && data.result != null) {
          return _buildReview(data.result!, actions);
        }
        if (data.questions != null && data.questions!.isNotEmpty) {
          // 初始化选项数组
          if (_selectedAnswers.length != data.questions!.length) {
            _selectedAnswers = List.filled(data.questions!.length, null);
          }
          return _buildQuestionFlow(data.questions!, actions);
        }
        return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.quiz, size: 48, color: AppColors.text2),
            SizedBox(height: 8),
            Text('今日暂无题目', style: TextStyle(color: AppColors.text2, fontSize: 16)),
          ]),
        );
      },
    );
  }

  // ---- 答题流程 ----
  Widget _buildQuestionFlow(List<QuizQuestion> questions, dynamic actions) {
    final total = questions.length;
    final q = questions[_currentIdx];
    final labels = ['A', 'B', 'C', 'D'];
    final progress = (_currentIdx + 1) / total;

    return Column(children: [
      // 进度条
      Container(
        height: 4,
        color: AppColors.surface2,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: MediaQuery.of(context).size.width * progress,
          color: AppColors.gold,
        ),
      ),
      // 题目头
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.surface,
        child: Row(children: [
          _categoryTag(q.category),
          const Spacer(),
          Text('$_currentIdx/$total', style: const TextStyle(color: AppColors.text2, fontSize: 12)),
        ]),
      ),
      // 题目内容
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 题干
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
              ),
              child: Text(q.question, style: const TextStyle(fontSize: 16, color: AppColors.text, height: 1.6)),
            ),
            const SizedBox(height: 20),
            // 选项
            ...List.generate(q.options.length, (j) {
              final letter = j < labels.length ? labels[j] : '$j';
              final isSelected = _selectedAnswers[_currentIdx] == letter;
              return _optionTile(letter, q.options[j], isSelected, () {
                setState(() => _selectedAnswers[_currentIdx] = letter);
              });
            }),
          ]),
        ),
      ),
      // 底部导航
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          // 上一题
          if (_currentIdx > 0)
            OutlinedButton(
              onPressed: () => setState(() => _currentIdx--),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('上一题'),
            )
          else
            const Spacer(),
          const Spacer(),
          // 下一题 / 提交
          if (_currentIdx < total - 1)
            ElevatedButton(
              onPressed: () => setState(() => _currentIdx++),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('下一题'),
            )
          else
            ElevatedButton.icon(
              onPressed: _submitting ? null : () => _handleSubmit(questions, actions),
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                  : const Icon(Icons.check, size: 18),
              label: Text(_submitting ? '提交中...' : '提交'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ]),
      ),
    ]);
  }

  Future<void> _handleSubmit(List<QuizQuestion> questions, dynamic actions) async {
    // 检查是否所有题都答了
    final unanswered = <int>[];
    for (int i = 0; i < questions.length; i++) {
      if (_selectedAnswers[i] == null || _selectedAnswers[i]!.isEmpty) {
        unanswered.add(i + 1);
      }
    }
    if (unanswered.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('提示', style: TextStyle(color: AppColors.text)),
          content: Text('第 ${unanswered.join(', ')} 题尚未作答，确定提交吗？', style: const TextStyle(color: AppColors.text2)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('继续答题', style: TextStyle(color: AppColors.text2))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doSubmit(questions, actions);
              },
              child: const Text('确定提交', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      );
      return;
    }
    _doSubmit(questions, actions);
  }

  Future<void> _doSubmit(List<QuizQuestion> questions, dynamic actions) async {
    setState(() => _submitting = true);
    try {
      final answers = List.generate(questions.length, (i) => {
            'question_id': questions[i].id,
            'user_answer': _selectedAnswers[i] ?? '',
          });
      await actions.submitQuiz(answers);
      ref.invalidate(todayQuizProvider);
      ref.invalidate(quizLeaderboardProvider);
      _selectedAnswers = [];
      _currentIdx = 0;
    } catch (e) {
      _snack('$e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  // ---- 回顾模式 ----
  Widget _buildReview(QuizResult result, dynamic actions) {
    final pct = result.total > 0 ? (result.score / result.total * 100).round() : 0;
    final correct = pct == 100;
    final bgColor = correct
        ? AppColors.success
        : pct >= 60
            ? AppColors.gold
            : AppColors.danger;
    final emoji = correct ? '🌟' : pct >= 80 ? '🎉' : pct >= 60 ? '👍' : '💪';

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 分数卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bgColor.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 4),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(children: [
                TextSpan(text: '${result.score}', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: bgColor)),
                TextSpan(text: ' / ${result.total}', style: const TextStyle(fontSize: 18, color: AppColors.text2)),
              ]),
            ),
            const SizedBox(height: 4),
            Text('正确率 $pct% · ${result.quizDate} · 今日已完成',
                style: const TextStyle(fontSize: 13, color: AppColors.text2)),
          ]),
        ),
        const SizedBox(height: 16),
        // 答题详情
        Text('答题详情', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 8),
        ...result.answers.asMap().entries.map((e) {
          final i = e.key;
          final a = e.value;
          final isCorrect = a.correct;
          final userLabel = a.userAnswer.isNotEmpty ? a.userAnswer : '未答';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.success.withValues(alpha: 0.06) : AppColors.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: isCorrect ? AppColors.success : AppColors.danger, width: 3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${a.question}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 6),
              Row(children: [
                Text('你的答案：', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                Text(userLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isCorrect ? AppColors.success : AppColors.danger)),
              ]),
              if (!isCorrect) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Text('正确答案：', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                  Text(a.correctAnswer, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                ]),
              ],
              if (a.explanation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(4)),
                  child: Text('💡 ${a.explanation}', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                ),
              ],
            ]),
          );
        }),
        const SizedBox(height: 12),
        // 查看排行榜按钮
        OutlinedButton.icon(
          onPressed: () => _tabCtrl.animateTo(1),
          icon: const Icon(Icons.leaderboard, size: 18),
          label: const Text('查看排行榜'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.gold),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  // ---- 公共组件 ----

  Widget _categoryTag(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Text(category, style: const TextStyle(fontSize: 11, color: AppColors.gold)),
    );
  }

  Widget _optionTile(String letter, String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.gold : AppColors.border, width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.gold : AppColors.surface2,
              border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
            ),
            child: Center(
              child: Text(letter,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? AppColors.bg : AppColors.text2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.text))),
        ]),
      ),
    );
  }

  // ==================== Tab 2: 排行榜 ====================

  Widget _buildLeaderboardTab() {
    final async = ref.watch(quizLeaderboardProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$e'.replaceFirst('Exception: ', ''), style: const TextStyle(color: AppColors.text2)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.invalidate(quizLeaderboardProvider),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bg),
            child: const Text('重试'),
          ),
        ]),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('本月暂无排行数据', style: TextStyle(color: AppColors.text2, fontSize: 15)));
        }
        final now = DateTime.now();
        final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: AppColors.surface,
              child: Row(children: [
                const Icon(Icons.emoji_events, color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Text('$month 排行榜', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final e = list[i];
                  final rankIcon = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      SizedBox(width: 30, child: Text(rankIcon, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text('${e.totalScore}分 · ${e.days}天', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
                        ]),
                      ),
                      // 点赞按钮
                      _likeButton(e, month),
                    ]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _likeButton(QuizLeaderboardEntry entry, String month) {
    return GestureDetector(
      onTap: () => _toggleLike(entry, month),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: entry.likedByMe ? AppColors.gold.withValues(alpha: 0.12) : AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: entry.likedByMe ? AppColors.gold.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(entry.likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: 14, color: entry.likedByMe ? AppColors.gold : AppColors.text2),
          const SizedBox(width: 4),
          Text('${entry.likes}', style: TextStyle(fontSize: 12, color: entry.likedByMe ? AppColors.gold : AppColors.text2)),
        ]),
      ),
    );
  }

  Future<void> _toggleLike(QuizLeaderboardEntry entry, String month) async {
    try {
      final actions = ref.read(adminActionsProvider);
      await actions.likeUser(entry.userId, month);
      ref.invalidate(quizLeaderboardProvider);
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.danger));
  }
}
