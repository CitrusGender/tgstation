import { createSearch } from 'common/string';
import { Box, Button, Input, Section } from '../components';
import { Window } from '../layouts';
import { useBackend, useLocalState } from '../backend';

export const Interview = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    questions,
  } = data;

  return (
    <Window>
      <Window.Content>
        <Section title="Interview Questions">
          <p>Please answer the following questions.</p>
          {questions.map(([qidx, question, response, comments]) => (
            <Box key={qidx}>
              <p>{question}</p>
              <Input value={response} />
            </Box>)
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
