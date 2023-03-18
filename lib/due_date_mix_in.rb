# lib/due_date_mix_in.rb
module DueDateMixIn
  def set_topic_by_user
    @participant = AssignmentParticipant.find(params[:id])
    @sel_topic_id = SignedUpTeam.topic_id(id, @participant.user_id)
  end
  # Check whether review, metareview, etc.. is allowed
  # The permissions of TopicDueDate is the same as AssignmentDueDate.
  # Here, column is usually something like 'review_allowed_id'
  def check_condition(column, topic_id = nil)
    next_due_date = DueDate.get_next_due_date(id, topic_id)
    return false if next_due_date.nil?

    right_id = next_due_date.send column
    right = DeadlineRight.find(right_id)
    # check is assignment action deadline is ok or late (i.e. not no)
    right && (right.name != 'No')
  end

  # Determine if the next due date from now allows for submissions
  def submission_allowed(assignment_id, participant_id)
    # check_condition('submission_allowed_id', topic_id)
    # @topic_id = SignedUpTeam.topic_id(@assignemnt.id,@participant.user_id)
    topic_id = SignedUpTeam.topic_id(id, participant_id)
    # only need to pass @particpiant to search, can this be done locally
    next_due_date = DueDate.get_next_due_date(id, topic_id)
    return false if next_due_date.nil?

    right_id = next_due_date.submission_allowed_id
    right = DeadlineRight.find(right_id)
    # check is assignment action deadline is ok or late (i.e. not no)
    right && (right.name != 'No')
  end
  # Determine if the next due date from now allows for reviews
  def can_review(topic_id = nil)
    check_condition('review_allowed_id', topic_id)
  end

  # Determine if the next due date from now allows for metareviews
  def metareview_allowed(topic_id = nil)
    check_condition('review_of_review_allowed_id', topic_id)
  end
  # if current  stage is submission or review, find the round number
  # otherwise, return 0
  def number_of_current_round(topic_id)
    next_due_date = DueDate.get_next_due_date(id, topic_id)
    return 0 if next_due_date.nil?

    next_due_date.round ||= 0
  end
  def link_for_current_stage(topic_id = nil)
    return nil if staggered_and_no_topic?(topic_id)

    due_date = find_current_stage(topic_id)
    if due_date.nil? || (due_date == 'Finished') || due_date.is_a?(TopicDueDate)
      return nil
    end

    due_date.description_url
  end
  def num_review_rounds
    due_dates = AssignmentDueDate.where(parent_id: id)
    rounds = 0
    due_dates.each do |due_date|
      rounds = due_date.round if due_date.round > rounds
    end
    rounds
  end

  def find_current_stage(topic_id = nil)
    next_due_date = DueDate.get_next_due_date(id, topic_id)
    return 'Finished' if next_due_date.nil?

    next_due_date
  end
  def find_due_dates(type)
    due_dates.select { |due_date| due_date.deadline_type_id == DeadlineType.find_by(name: type).id }
  end

  # Method find_review_period is used in answer_helper.rb to get the start and end dates of a round
  def find_review_period(round)
    # If round is nil, it means the same questionnaire is used for every round. Thus, we return all periods.
    # If round is not nil, we return only the period of that round.

    submission_type = DeadlineType.find_by(name: 'submission').id
    review_type = DeadlineType.find_by(name: 'review').id

    due_dates = []
    due_dates += find_due_dates('submission')
    due_dates += find_due_dates('review')
    due_dates.sort_by!(&:id)

    start_dates = []
    end_dates = []

    if round.nil?
      round = 1
      while self.due_dates.exists?(round: round)
        start_dates << due_dates.select { |due_date| due_date.deadline_type_id == submission_type && due_date.round == round }.last
        end_dates << due_dates.select { |due_date| due_date.deadline_type_id == review_type && due_date.round == round }.last
        round += 1
      end
    else
      start_dates << due_dates.select { |due_date| due_date.deadline_type_id == submission_type && due_date.round == round }.last
      end_dates << due_dates.select { |due_date| due_date.deadline_type_id == review_type && due_date.round == round }.last
    end
    [start_dates, end_dates]
  end

  # END OF MODULE #
end