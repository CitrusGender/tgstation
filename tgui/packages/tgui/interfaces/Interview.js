import { Button, TextArea, Section, BlockQuote, NoticeBox } from '../components';
import { Window } from '../layouts';
import { useBackend } from '../backend';

export const Interview = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    questions,
    read_only,
    queue_pos,
  } = data;

  return (
    <Window>
      <Window.Content scrollable>
        {(!read_only && (
          <Section title="Welcome!">
            <p>
              Welcome to our server. As you have not played here before, or
              played very little, we&apos;ll need you to answer a few questions
              below. After you submit your answers they will be reviewed
              and you may be asked further questions before being allowed to
              play. Please be patient as there may be others ahead of you.
            </p>
          </Section>)) || (
          <NoticeBox info>
            Your answers have been submitted. You are position {queue_pos} in
            queue.
          </NoticeBox>
        )}
        <Section
          title="Questionnaire"
          buttons={(
            <Button
              content={read_only ? "Submitted" : "Submit"}
              onClick={() => act('submit')}
              disabled={read_only} />
          )}>
          {!read_only && (
            <p>
              Please answer the following questions,
              and press submit when you are satisfied with your answers.
            </p>)}
          {questions.map(({ qidx, question, response }) => (
            <Section key={qidx} title={`Question ${qidx}`}>
              <p>{question}</p>
              {(read_only && (
                <BlockQuote>{response || "No response."}</BlockQuote>)) || (
                <TextArea
                  value={response}
                  fluid
                  height={10}
                  maxLength={500}
                  placeholder="Write your response here, max of 500 characters."
                  onChange={(e, input) => input !== response
                    && act('update_answer', {
                      qidx: qidx,
                      answer: input,
                    })} />)}
            </Section>)
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
