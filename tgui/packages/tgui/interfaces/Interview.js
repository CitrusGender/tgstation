import { createSearch } from 'common/string';
import { Box, Button, TextArea, Section } from '../components';
import { Window } from '../layouts';
import { useBackend, useLocalState } from '../backend';

export const Interview = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    questions,
  } = data;

  return (
    <Window>
      <Window.Content scrollable>
        <Section
          title="Interview Questions"
          buttons={(
            <Button
              content="Submit"
              onClick={() => act('submit')} />
          )}>
          <p>Please answer the following questions</p>
          {questions.map(({ qidx, question, response }) => (
            <Section key={qidx} title={`Question ${qidx}`}>
              <p>{question}</p>
              <TextArea
                value={response}
                fluid
                maxLength={512}
                height={10}
                onChange={(e, input) => act('update_answer', {
                  qidx: qidx,
                  answer: input,
                })} />
            </Section>)
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
